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

/// spawn 时递给 worker 的启动载荷：应答口、受控日志路径与归档阈值。
final class WorkerConfig {
  const WorkerConfig({
    required this.replyTo,
    required this.path,
    this.maxLogBytes = IsolatedErrorLogSink.defaultMaxLogBytes,
  });

  final SendPort replyTo;
  final String path;

  /// 归档滚动阈值（字节）—— [_logWorkerEntry] 启动时与
  /// [_writePackSync] 每次追加前各检查一次，越阈即单代归档。
  final int maxLogBytes;
}

/// worker isolate 入口（Isolate.spawn 要求顶层函数）。
///
/// 写盘语义镜像 ErrorLogFileSink 的 writeAsString append 逐次开合：
/// append 打开（不存在则创建）→ UTF-8 写入 → flush。写失败绝不外溢，
/// 以 [_WriteFailed]（errorType-only）回流主侧失败门。
///
/// 启动归档：握手发出后、进入消息循环前先做一次阈值归档——上一会话
/// 遗留的超限日志无需等待本次会话首次写即被归档（send 与归档之间无
/// await，main 收到握手时归档已同步完成）。
Future<void> _logWorkerEntry(WorkerConfig config) async {
  final requestPort = ReceivePort();
  config.replyTo.send(_WorkerHandshake(requestPort.sendPort));
  _rollArchiveSync(config.path, config.maxLogBytes);
  await for (final message in requestPort) {
    switch (message) {
      case _WriteRequest(:final id, :final pack):
        config.replyTo.send(
          _writePackSync(config.path, config.maxLogBytes, id, pack),
        );
      case _DrainRequest(:final id):
        config.replyTo.send(_DrainOk(id));
      case _CloseRequest(:final id):
        // 最终消息经就绪口回流（Isolate.exit 保证送达）后立即退出；
        // 请求口随 exit 一并关闭，此后到达的请求被丢弃。
        Isolate.exit(config.replyTo, _ClosedOk(id));
    }
  }
}

/// 尺寸阈值归档滚动（单代策略，fail-open）—— error.log 达到
/// [maxLogBytes] 即整体 rename 为固定后缀 `error.log.1`，旧归档被
/// 直接替换，目录内恒至多一份归档；活动文件从零重新增长。
///
/// 红线：归档由 rename 产生，磁盘字节从不改写；每个文件系统操作各自
/// 包容失败静默返回（T-261009-fip-01）——滚动失败绝不让写路径失败、
/// 绝不回流 [_WriteFailed]、绝不触碰失败门，追加照旧落在仍在原位的
/// 活动文件上，下次写时滚动自动重试。
void _rollArchiveSync(String path, int maxLogBytes) {
  final int length;
  try {
    // 存在性与字节数检查：活动文件不存在（首轮写/刚被外部清理）直接跳过。
    final file = File(path);
    if (!file.existsSync()) {
      return;
    }
    length = file.lengthSync();
  } on Object {
    // stat 失败视同未达阈：滚动是尽力而为的维护，不是写的前置条件。
    return;
  }
  if (length < maxLogBytes) {
    return;
  }
  // 归档目标为已解析日志路径的固定后缀兄弟（同目录、无用户输入成分）。
  final archivePath = '$path.1';
  try {
    // 旧归档先删（best-effort）：删除失败则放弃本次滚动，保留现场。
    final archive = File(archivePath);
    if (archive.existsSync()) {
      archive.deleteSync();
    }
  } on Object {
    return;
  }
  try {
    // rename 原子替换：句柄不驻留（每消息现开现关），Windows 上
    // 两次写之间 rename 恒安全。
    File(path).renameSync(archivePath);
  } on Object {
    // rename 失败：活动文件原位保留，本次追加继续写入它。
    return;
  }
}

/// 同步写一个 pack：追加前先做阈值归档，每消息现开现关句柄，成功回
/// _WriteOk，失败回 _WriteFailed（sealed 应答组）。
///
/// 为什么不持常驻句柄：空闲期 worker 零 OS 句柄，既有消费者的 teardown
/// 删临时目录（diagnostic_log_target_test）与 fire-and-forget dispose
/// （general_settings_content_test）都不会被常驻 worker 阻塞；同时也
/// 是滚动 rename 的安全前提（写与 rename 永不同时持句柄）。
_WorkerToMain _writePackSync(
  String path,
  int maxLogBytes,
  int id,
  String pack,
) {
  // 追加前滚动：越阈活动文件先归档，本条与后续记录落全新 error.log。
  _rollArchiveSync(path, maxLogBytes);
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
/// [WorkerConfig] 为公开类型：public typedef 不得引用私有类型
/// （library_private_types_in_public_api）。
typedef WorkerSpawner = Future<Isolate> Function(
  void Function(WorkerConfig config) entry,
  WorkerConfig config, {
  SendPort? onExit,
  SendPort? onError,
});

/// 默认 spawn 实现。
///
/// 显式 errorsAreFatal: false 使 worker 自容错：单条写失败经 _WriteFailed
/// 回流主侧，绝不让未捕获异常把 isolate 整体带走；真正的意外死亡由
/// onExit/onError 兜底降级。
Future<Isolate> _defaultSpawnWorker(
  void Function(WorkerConfig config) entry,
  WorkerConfig config, {
  SendPort? onExit,
  SendPort? onError,
}) => Isolate.spawn(
  entry,
  config,
  onExit: onExit,
  onError: onError,
  errorsAreFatal: false,
);
