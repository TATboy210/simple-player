/// 常驻 logging isolate 日志 sink —— 主 isolate 卡死时已递送记录仍落盘。
///
/// Durable error-log sink whose write execution lives in a resident logging
/// isolate: when the main isolate's event loop freezes, every already-handed
/// record is still written and flushed by the worker, and the gap between
/// heartbeat lines reads as the frozen window.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'diagnostic_pack_formatter.dart';
import 'error_log_file_sink.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';
import 'kernel_logger.dart';

// Worker 协议/入口/spawn 缝位于同一 library 的 part 文件（文件尺寸预算）。
part 'isolated_error_log_sink_worker.dart';

/// 主 isolate 卡死容忍的日志 sink —— 写入执行位置挪进常驻 logging isolate。
///
/// 对调用方的可观察语义与 [ErrorLogFileSink] 逐项一致：severity 门（仅
/// error/fatal）、append + UTF-8 + flush 逐条写、record 序 = 落盘序、drain
/// 可重入、dispose 幂等、logsAvailable 失败置假/成功恢复、失败上报首条 +
/// 每 50 条限流。降级（spawn 失败/worker 死亡/关闭后）幂等回退到
/// [ErrorLogFileSink] 直写，捕获链永不阻断，绝不双写。
final class IsolatedErrorLogSink implements DiagnosticLogSink {
  /// Reports the first and every fiftieth consecutive failure to avoid
  /// turning an unavailable disk into a diagnostic-output flood.
  static const int _failureReportInterval = 50;

  /// Creates a sink that hands formatted packs to a resident logging isolate.
  ///
  /// Worker spawn starts immediately; spawn failure never throws out of the
  /// constructor (degradation is handled internally).
  ///
  /// [spawnWorker] 仅为测试注入缝；[heartbeatInterval] 默认 30s，心跳空档
  /// 即主 isolate 卡死时间窗的运营读数（headless 不可单测时间窗本身）。
  IsolatedErrorLogSink({
    required File file,
    void Function(Object error, StackTrace stackTrace)? degradedOutput,
    @visibleForTesting WorkerSpawner? spawnWorker,
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) : _file = file,
       _path = file.path,
       _degradedOutput = degradedOutput ?? _defaultDegradedOutput,
       _spawnWorker = spawnWorker ?? _defaultSpawnWorker,
       _heartbeatInterval = heartbeatInterval {
    _startWorker();
  }

  final File _file;

  /// 受控日志路径快照 —— worker 配置与 pack 的 Log Path 段共用同一读数。
  final String _path;
  final WorkerSpawner _spawnWorker;
  final Duration _heartbeatInterval;
  final void Function(Object error, StackTrace stackTrace) _degradedOutput;

  /// Stable availability state for a future non-modal presentation.
  @override
  final ValueNotifier<bool> logsAvailable = ValueNotifier<bool>(true);

  /// 握手前到达的记录缓冲（原始 report 对，降级重放需重格式化）。
  final ListQueue<(ErrorReport, ReportAcceptance)> _pending =
      ListQueue<(ErrorReport, ReportAcceptance)>();

  /// drain/close 应答按 id 关联的 Completer 表。
  final Map<int, Completer<void>> _drainAcks = <int, Completer<void>>{};
  final Map<int, Completer<void>> _closeAcks = <int, Completer<void>>{};

  int _consecutiveFailures = 0;
  int _nextId = 0;
  SendPort? _requestPort;

  /// 握手完成（或降级接管的后续任务）信号 —— drain/dispose 的推进点。
  final Completer<void> _modeReady = Completer<void>();

  bool _closed = false;
  bool _degraded = false;
  bool _receivedClosedOk = false;
  Future<void>? _disposeFuture;
  ErrorLogFileSink? _fallback;
  Timer? _heartbeatTimer;
  ReceivePort? _readyPort;
  ReceivePort? _exitPort;
  ReceivePort? _errorPort;

  /// 供测试轮询降级完成（消除 kill→onExit 事件竞态）。
  @visibleForTesting
  bool get isDegradedForTesting => _degraded;

  /// Accepts an ErrorReporter effect call and queues eligible durable evidence.
  ///
  /// 永不上抛（effect 契约）：关断/降级后经回退直写，握手前缓冲，其余经
  /// severity 门格式化后递送 worker。
  @override
  void record(ErrorReport report, ReportAcceptance acceptance) {
    if (_closed || _degraded) {
      _ensureFallback()?.record(report, acceptance);
      return;
    }
    if (_requestPort == null) {
      // 握手前缓冲原始 (report, acceptance) 对：降级重放需要原始 report
      // 经 fallback.record 重格式化（formatDiagnosticPack 纯函数输出一致）。
      _pending.addLast((report, acceptance));
      return;
    }
    _dispatchToIsolate(report);
  }

  /// Waits for all writes observed before this call without closing the sink.
  ///
  /// Repeated calls are safe: each drain carries its own id-correlated ack.
  /// drain 不在 DiagnosticLogSink 接口内（同 ErrorLogFileSink 的额外能力）。
  Future<void> drain() async {
    await _modeReady.future;
    if (_closed || _degraded) {
      // 降级路径：等待回退链完成（含缓冲重放的直写）。
      final fallback = _ensureFallback();
      return fallback?.drain() ?? Future<void>.value();
    }
    final requestPort = _requestPort;
    if (requestPort == null) {
      // 不可达防御：modeReady 只在握手/降级后完成。兜底避免任何路径挂死。
      return;
    }
    final id = ++_nextId;
    final ack = Completer<void>();
    _drainAcks[id] = ack;
    requestPort.send(_DrainRequest(id));
    await ack.future;
  }

  /// Drains queued writes for lifecycle shutdown; the sink remains reusable.
  ///
  /// 记忆化 Future 保证幂等：重复调用返回同一 Future，不重复关闭。
  @override
  Future<void> dispose() => _disposeFuture ??= _disposeNow();

  /// Sends the close request and awaits the worker's final message.
  Future<void> _disposeNow() async {
    await _modeReady.future;
    // dispose 与降级两路径都必须 cancel 心跳（T-EYW-05 生命周期纪律）。
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final requestPort = _requestPort;
    if (_closed || _degraded || requestPort == null) {
      _closed = true;
      final fallback = _fallback;
      if (fallback != null) {
        await fallback.dispose();
      }
      return;
    }
    final id = ++_nextId;
    final ack = Completer<void>();
    _closeAcks[id] = ack;
    requestPort.send(_CloseRequest(id));
    await ack.future;
    _closed = true;
    _closeWorkerPorts();
    // 关闭确认与降级竞争时兜底释放回退链（无 OS 句柄，幂等无害）。
    final fallback = _fallback;
    if (_degraded && fallback != null) {
      await fallback.dispose();
    }
  }

  /// 关闭主侧三个监听口（干净关闭与降级共用）。
  ///
  /// Side effect: 就绪口/退出口/错误口不再接收任何消息；worker 已退出的
  /// onExit 空消息会被安全丢弃。
  void _closeWorkerPorts() {
    _readyPort?.close();
    _readyPort = null;
    _exitPort?.close();
    _exitPort = null;
    _errorPort?.close();
    _errorPort = null;
  }

  /// 派生常驻 worker：建就绪口与退出/错误口，经注入缝 spawn 并监听应答。
  void _startWorker() {
    final readyPort = ReceivePort();
    final exitPort = ReceivePort();
    final errorPort = ReceivePort();
    _readyPort = readyPort;
    _exitPort = exitPort;
    _errorPort = errorPort;
    readyPort.listen(_handleWorkerMessage);
    // onExit/onError 都汇入幂等 _handleWorkerGone（干净关闭静默收尾）。
    exitPort.listen((_) => _handleWorkerGone());
    errorPort.listen((_) => _handleWorkerGone());
    try {
      // 同步 spawn 失败立即降级；异步失败经 then/onError 汇入同一幂等路径。
      unawaited(
        _spawnWorker(
          _logWorkerEntry,
          _WorkerConfig(replyTo: readyPort.sendPort, path: _path),
          onExit: exitPort.sendPort,
          onError: errorPort.sendPort,
        ).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            _handleWorkerGone();
          },
        ),
      );
    } on Object {
      // 同步 spawn 失败（注入假缝或环境拒绝）：降级永不外溢。
      _handleWorkerGone();
    }
  }

  /// 就绪口唯一监听：握手 → 存请求口 → flush 缓冲 → 放行 drain/dispose。
  void _handleWorkerMessage(Object? message) {
    // 协议只含 sealed 私有类型；未知消息静默忽略（前向兼容）。
    if (message is! _WorkerToMain) {
      return;
    }
    switch (message) {
      case _WorkerHandshake(:final requestPort):
        _requestPort = requestPort;
        _flushPending();
        _startHeartbeat();
        if (!_modeReady.isCompleted) {
          _modeReady.complete();
        }
      case _WriteOk():
        _consecutiveFailures = 0;
        logsAvailable.value = true;
      case _WriteFailed(:final errorType):
        _containWriteFailure(errorType);
      case _DrainOk(:final id):
        _drainAcks.remove(id)?.complete();
      case _ClosedOk(:final id):
        // 先于 onExit 空消息到达（Isolate.exit 的最终消息保证先发）：
        // 标记干净关闭，使随后的 _handleWorkerGone 不误降级。
        _receivedClosedOk = true;
        _closeAcks.remove(id)?.complete();
    }
  }

  /// worker 退出/出错兜底：干净关闭只收尾端口，意外退出幂等降级。
  void _handleWorkerGone() {
    if (_closed || _receivedClosedOk || _degraded) {
      _closeWorkerPorts();
      return;
    }
    _degradeAndReplay();
  }

  /// 幂等降级（once-guard）：cancel 心跳 → 缓冲重放 → 放行未决 drain/dispose。
  ///
  /// Side effect: 请求口置空、主侧监听口全关、后续 record 直通回退链；
  /// 降级全程不上抛（D-01/D-02 静默失败哲学），模式切换不触碰失败门读数。
  void _degradeAndReplay() {
    if (_degraded || _closed) {
      return;
    }
    _degraded = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _requestPort = null;
    _closeWorkerPorts();
    // 缓冲重放：原始 report 经 fallback.record 重格式化
    // （formatDiagnosticPack 纯函数输出逐字符一致，绝不双写）。
    while (_pending.isNotEmpty) {
      final (report, acceptance) = _pending.removeFirst();
      _ensureFallback()?.record(report, acceptance);
    }
    if (!_modeReady.isCompleted) {
      _modeReady.complete();
    }
    // 未决 drain/close 应答直接放行，避免 worker 死亡后挂死调用方。
    for (final ack in _drainAcks.values) {
      ack.complete();
    }
    _drainAcks.clear();
    for (final ack in _closeAcks.values) {
      ack.complete();
    }
    _closeAcks.clear();
  }

  /// 握手后启动心跳 Timer：tick 经写请求通道落盘心跳行。
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// 心跳 tick：缓冲期/降级期/关闭期直接丢弃（错过一条 30s 心跳无害）。
  ///
  /// 心跳不经 severity 门，但共享 ack 失败门（磁盘健康信号语义一致）。
  void _sendHeartbeat() {
    if (_closed || _degraded) {
      return;
    }
    final requestPort = _requestPort;
    if (requestPort == null) {
      return;
    }
    requestPort.send(_WriteRequest(++_nextId, _heartbeatLine()));
  }

  /// 心跳行（钦定格式）：单行、可 grep（'main alive'）、单 \n 结尾，
  /// 与报告块的双 \n 结尾形成视觉区分。
  static String _heartbeatLine() =>
      '[heartbeat] main alive @ ${DateTime.now().toUtc().toIso8601String()}\n';

  /// 握手后一次性回放缓冲记录（逐条 severity 门 + 格式化 + 发送）。
  void _flushPending() {
    while (_pending.isNotEmpty) {
      final (report, _) = _pending.removeFirst();
      _dispatchToIsolate(report);
    }
  }

  /// severity 门 + 格式化 + 发送写请求（与 ErrorLogFileSink 门语义一致）。
  void _dispatchToIsolate(ErrorReport report) {
    if (!_isPersistentSeverity(report.severity)) {
      return;
    }
    final String pack;
    try {
      pack = '${formatDiagnosticPack(report, logPath: _path)}\n\n';
    } on Object catch (error) {
      // 格式化失败视同写失败进入失败门，不阻断捕获链。
      _containWriteFailure(error.runtimeType.toString());
      return;
    }
    _requestPort?.send(_WriteRequest(++_nextId, pack));
  }

  /// 失败门：计数、置假、限流上报（errorType-only 纪律）。
  void _containWriteFailure(String errorType) {
    _consecutiveFailures += 1;
    logsAvailable.value = false;
    if (_shouldReportFailure(_consecutiveFailures)) {
      _emitDegradedOutput(StateError(errorType));
    }
  }

  /// 包 try 的降级输出唯一出口（终态容器，绝不回流 effect 链）。
  void _emitDegradedOutput(Object error) {
    try {
      _degradedOutput(error, StackTrace.empty);
    } on Object {
      // 降级输出自身失败不再上报，避免递归外溢。
    }
  }

  /// 惰性构造降级回退 sink（[ErrorLogFileSink] 本体，冻结契约零 diff）。
  ///
  /// 构造不可达失败时丢弃并上报降级、返回 null（调用方静默丢弃该记录），
  /// 保证 record/dispose 路径永不因降级而上抛。回退链的可用性读数前向
  /// 同步到本 sink 的 notifier，保持「logsAvailable 失败置假/成功恢复」
  /// 对 delegate 消费者的既有语义。
  ErrorLogFileSink? _ensureFallback() {
    final existing = _fallback;
    if (existing != null) {
      return existing;
    }
    try {
      final fallback = ErrorLogFileSink(
        file: _file,
        degradedOutput: _degradedOutput,
      );
      fallback.logsAvailable.addListener(_syncFallbackAvailability);
      return _fallback = fallback;
    } on Object catch (error) {
      _emitDegradedOutput(error);
      return null;
    }
  }

  /// 回退链可用性 → 本 sink notifier 的单向同步（降级期唯一写点）。
  void _syncFallbackAvailability() {
    final fallback = _fallback;
    if (fallback != null) {
      logsAvailable.value = fallback.logsAvailable.value;
    }
  }

  /// Keeps failure reporting observable without recursively producing an
  /// outage.
  bool _shouldReportFailure(int count) =>
      count == 1 || count % _failureReportInterval == 0;

  /// Reuses the kernel logger facade and contains uninitialized-logger
  /// failures.
  static void _defaultDegradedOutput(Object error, StackTrace stackTrace) {
    try {
      KernelLogger.I.warn(
        'Diagnostic file evidence is unavailable.',
        context: <String, Object?>{'errorType': error.runtimeType.toString()},
      );
    } on Object {
      // Startup may report before KernelLogger initialization; never recurse.
    }
  }

  /// Ensures warning-only reports never reach the filesystem boundary.
  bool _isPersistentSeverity(ErrorSeverity severity) =>
      severity == ErrorSeverity.error || severity == ErrorSeverity.fatal;
}
