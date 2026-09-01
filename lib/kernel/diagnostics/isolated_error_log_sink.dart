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

/// 主 isolate → worker isolate 的请求消息。
///
/// 私有 sealed 协议；同 isolate 组内对象可直接经 SendPort 递送。
sealed class _MainToWorker {
  const _MainToWorker();
}

/// 追加写入一个已格式化诊断包。
final class _WriteRequest extends _MainToWorker {
  const _WriteRequest(this.id, this.pack);

  final int id;
  final String pack;
}

/// 同步点 —— drain 等待此前全部写入请求处理完成。
final class _DrainRequest extends _MainToWorker {
  const _DrainRequest(this.id);

  final int id;
}

/// 优雅关闭 —— worker 处理完此前全部请求后携带最终消息退出。
final class _CloseRequest extends _MainToWorker {
  const _CloseRequest(this.id);

  final int id;
}

/// worker isolate → 主 isolate 的应答消息。
sealed class _WorkerToMain {
  const _WorkerToMain();
}

/// 握手 —— worker 就绪并交出请求口。
final class _WorkerHandshake extends _WorkerToMain {
  const _WorkerHandshake(this.requestPort);

  final SendPort requestPort;
}

/// 单条写入成功。
final class _WriteOk extends _WorkerToMain {
  const _WriteOk(this.id);

  final int id;
}

/// drain 同步点完成。
final class _DrainOk extends _WorkerToMain {
  const _DrainOk(this.id);

  final int id;
}

/// 优雅关闭完成（Isolate.exit 的最终消息）。
final class _ClosedOk extends _WorkerToMain {
  const _ClosedOk(this.id);

  final int id;
}

/// 单条写入失败 —— 只回 errorType 字符串，不跨 SendPort 传 message。
final class _WriteFailed extends _WorkerToMain {
  const _WriteFailed(this.id, this.errorType);

  final int id;
  final String errorType;
}

/// spawn 时递给 worker 的启动载荷：应答口与受控日志路径。
final class _WorkerConfig {
  const _WorkerConfig({required this.replyTo, required this.path});

  final SendPort replyTo;
  final String path;
}

/// worker isolate 入口（Isolate.spawn 要求顶层函数）。
///
/// 写盘语义镜像 ErrorLogFileSink 的 writeAsString append 逐次开合：
/// append 打开（不存在则创建）→ UTF-8 写入 → flush。写失败绝不外溢，
/// 以 [_WriteFailed]（errorType-only）回流主侧失败门。
Future<void> _logWorkerEntry(_WorkerConfig config) async {
  final requestPort = ReceivePort();
  config.replyTo.send(_WorkerHandshake(requestPort.sendPort));
  await for (final message in requestPort) {
    switch (message) {
      case _WriteRequest(:final id, :final pack):
        config.replyTo.send(_writePackSync(config.path, id, pack));
      case _DrainRequest(:final id):
        config.replyTo.send(_DrainOk(id));
      case _CloseRequest(:final id):
        // 最终消息经就绪口回流（Isolate.exit 保证送达）后立即退出；
        // 请求口随 exit 一并关闭，此后到达的请求被丢弃。
        Isolate.exit(config.replyTo, _ClosedOk(id));
    }
  }
}

/// 同步写一个 pack：每消息现开现关句柄。
///
/// 为什么不持常驻句柄：空闲期 worker 零 OS 句柄，既有消费者的 teardown
/// 删临时目录（diagnostic_log_target_test）与 fire-and-forget dispose
/// （general_settings_content_test）都不会被常驻 worker 阻塞。
/// 成功回 _WriteOk，失败回 _WriteFailed（sealed 应答组）。
_WorkerToMain _writePackSync(String path, int id, String pack) {
  RandomAccessFile? handle;
  try {
    // 用非空局部承接句柄：写/flush 走非空变量；try 内赋值的可空局部
    // 不参与空安全提升。
    final opened = File(path).openSync(mode: FileMode.append);
    handle = opened;
    opened.writeStringSync(pack, encoding: utf8);
    opened.flushSync();
    return _WriteOk(id);
  } on Object catch (error) {
    // errorType-only 纪律：与 _defaultDegradedOutput 一致，只传 runtimeType
    // 字符串，不把诊断 message 带出子 isolate。
    return _WriteFailed(id, error.runtimeType.toString());
  } finally {
    // best-effort 关闭：清理失败不改变已判定的写结果（D-01 静默失败哲学）。
    try {
      handle?.closeSync();
    } on Object {
      // 句柄可能已随写失败失效；忽略清理异常。
    }
  }
}

/// 默认 spawn 实现。
///
/// 显式 errorsAreFatal: false 使 worker 自容错：单条写失败经 _WriteFailed
/// 回流主侧，绝不让未捕获异常把 isolate 整体带走；真正的意外死亡由
/// onExit/onError 兜底降级。
Future<Isolate> _defaultSpawnWorker(
  void Function(_WorkerConfig config) entry,
  _WorkerConfig config, {
  SendPort? onExit,
  SendPort? onError,
}) => Isolate.spawn(
  entry,
  config,
  onExit: onExit,
  onError: onError,
  errorsAreFatal: false,
);

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
  IsolatedErrorLogSink({
    required File file,
    void Function(Object error, StackTrace stackTrace)? degradedOutput,
  }) : _file = file,
       _path = file.path,
       _degradedOutput = degradedOutput ?? _defaultDegradedOutput {
    _startWorker();
  }

  final File _file;

  /// 受控日志路径快照 —— worker 配置与 pack 的 Log Path 段共用同一读数。
  final String _path;
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
  Future<void>? _disposeFuture;
  ErrorLogFileSink? _fallback;
  ReceivePort? _readyPort;
  ReceivePort? _exitPort;
  ReceivePort? _errorPort;

  /// Accepts an ErrorReporter effect call and queues eligible durable evidence.
  ///
  /// 永不上抛（effect 契约）：关断后经回退直写，握手前缓冲，其余经
  /// severity 门格式化后递送 worker。
  @override
  void record(ErrorReport report, ReportAcceptance acceptance) {
    if (_closed) {
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
    if (_closed) {
      final fallback = _ensureFallback();
      return fallback?.drain() ?? Future<void>.value();
    }
    final requestPort = _requestPort;
    if (requestPort == null) {
      // 不可达防御：modeReady 只在握手后完成。兜底避免任何路径挂死。
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
    final requestPort = _requestPort;
    if (_closed || requestPort == null) {
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

  /// 派生常驻 worker：建就绪口与退出/错误口，spawn 并监听应答。
  void _startWorker() {
    final readyPort = ReceivePort();
    final exitPort = ReceivePort();
    final errorPort = ReceivePort();
    _readyPort = readyPort;
    _exitPort = exitPort;
    _errorPort = errorPort;
    readyPort.listen(_handleWorkerMessage);
    // onExit/onError 都汇入幂等 _handleWorkerGone（降级编排在后续任务填充）。
    exitPort.listen((_) => _handleWorkerGone());
    errorPort.listen((_) => _handleWorkerGone());
    // spawn Future 的异步失败同样汇入 _handleWorkerGone，绝不外溢。
    unawaited(
      _defaultSpawnWorker(
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
        _modeReady.complete();
      case _WriteOk():
        _consecutiveFailures = 0;
        logsAvailable.value = true;
      case _WriteFailed(:final errorType):
        _containWriteFailure(errorType);
      case _DrainOk(:final id):
        _drainAcks.remove(id)?.complete();
      case _ClosedOk(:final id):
        _closeAcks.remove(id)?.complete();
    }
  }

  /// worker 退出/出错兜底 —— 降级编排在后续任务填充（当前留空）。
  void _handleWorkerGone() {}

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
  /// 保证 record/dispose 路径永不因降级而上抛。
  ErrorLogFileSink? _ensureFallback() {
    final existing = _fallback;
    if (existing != null) {
      return existing;
    }
    try {
      return _fallback = ErrorLogFileSink(
        file: _file,
        degradedOutput: _degradedOutput,
      );
    } on Object catch (error) {
      _emitDegradedOutput(error);
      return null;
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
