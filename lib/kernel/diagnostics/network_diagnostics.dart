library;

import 'dart:io';

import 'kernel_logger.dart';

/// 网络接口快照 — 纯数据 record (B5/9 诊断值, 不含 IP/接口名).
typedef NetworkInterfaceSnapshot = ({int interfaceCount, bool hasNonLoopback});

/// 可注入的网络接口枚举器 — 测试用 fake 替身, 不依赖真实网络.
typedef NetworkInterfaceEnumerator =
    Future<List<({bool isLoopback})>> Function();

/// 采集本机网络接口摘要 — 网络流打开失败时附带进 ErrorContext 供"出错可定位"
/// 回溯. 静默降级: 枚举/超时/异常均返回 null, 不阻断错误处理主路径.
///
/// 261009-roy S2/F5: catch 面收窄 — `on Exception`（超时/Socket 等操作异常）
/// 保持既有静默降级语义; Error 族（非 Exception, 编程态/环境态破坏）不再
/// 无输出吞, 先记 error 级诊断日志再降级 null, 满足「出错可定位」回溯
/// （logger 未注入且 KernelLogger 未 init 时经 WR-02 探针跳过日志, 降级
/// 语义不变）。
Future<NetworkInterfaceSnapshot?> collectNetworkSnapshot({
  NetworkInterfaceEnumerator? enumerate,
  Duration timeout = const Duration(seconds: 2),
  KernelLogger? logger,
}) async {
  try {
    final interfaces = await (enumerate ?? _defaultEnumerate)().timeout(
      timeout,
    );
    return (
      interfaceCount: interfaces.length,
      hasNonLoopback: interfaces.any((i) => !i.isLoopback),
    );
  } on Exception {
    return null; // 操作异常（超时/Socket）— 既有静默降级语义不变.
  } on Object catch (error, stackTrace) {
    // S2/F5: Error 族先记诊断日志再降级 — 不再静默吞.
    final log = logger ?? _probeLogger();
    log?.error(
      'collectNetworkSnapshot: enumerator threw non-Exception Error — '
      'degraded to null snapshot',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// WR-02 探针 — KernelLogger 未初始化时返回 null（调用点 `?.` 安全跳过）,
/// 避免 Error 防御分支自己抛 StateError（照 KernelLoggerImpl.isInitialized
/// 先例 / thumbnail_disk_cache._logWarn 包裹同族降级）。
KernelLogger? _probeLogger() =>
    KernelLoggerImpl.isInitialized ? KernelLogger.I : null;

/// 默认枚举器 — NetworkInterface.list (B0 探针 GO: named params 可用),
/// 投影为最小形状供上层聚合.
Future<List<({bool isLoopback})>> _defaultEnumerate() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: true,
    type: InternetAddressType.any,
  );
  // NetworkInterface 无 isLoopback getter — 从 addresses 投影 (InterfaceAddress
  // implements InternetAddress, 继承 isLoopback).
  return [
    for (final i in interfaces)
      (isLoopback: i.addresses.any((a) => a.isLoopback)),
  ];
}
