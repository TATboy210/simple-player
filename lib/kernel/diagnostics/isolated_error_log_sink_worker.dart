// 隔离日志 sink 的 worker 侧实现（同一 library 的 part 文件）。
//
// Protocol classes, worker isolate entry, and spawn seam for the resident
// logging isolate. Private symbols are shared with the parent library
// (`isolated_error_log_sink.dart`) via `part` — the isolate message protocol
// stays library-private while keeping each file under the project's size
// budget.
part of 'isolated_error_log_sink.dart';

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

/// 同步写一个 pack：每消息现开现关句柄，成功回 _WriteOk，失败回
/// _WriteFailed（sealed 应答组）。
///
/// 为什么不持常驻句柄：空闲期 worker 零 OS 句柄，既有消费者的 teardown
/// 删临时目录（diagnostic_log_target_test）与 fire-and-forget dispose
/// （general_settings_content_test）都不会被常驻 worker 阻塞。
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

/// spawn 实现缝 —— 默认 [_defaultSpawnWorker]；仅测试注入假缝。
///
/// 参数类型含私有 [_WorkerConfig]：外部使用方经闭包推断获得类型，无需命名。
typedef WorkerSpawner = Future<Isolate> Function(
  void Function(_WorkerConfig config) entry,
  _WorkerConfig config, {
  SendPort? onExit,
  SendPort? onError,
});

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
