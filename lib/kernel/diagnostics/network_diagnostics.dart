library;

import 'dart:io';

/// 网络接口快照 — 纯数据 record (B5/9 诊断值, 不含 IP/接口名).
typedef NetworkInterfaceSnapshot = ({int interfaceCount, bool hasNonLoopback});

/// 可注入的网络接口枚举器 — 测试用 fake 替身, 不依赖真实网络.
typedef NetworkInterfaceEnumerator = Future<List<({bool isLoopback})>> Function();

/// 采集本机网络接口摘要 — 网络流打开失败时附带进 ErrorContext 供"出错可定位"
/// 回溯. 静默降级: 枚举/超时/异常均返回 null, 不阻断错误处理主路径.
Future<NetworkInterfaceSnapshot?> collectNetworkSnapshot({
  NetworkInterfaceEnumerator? enumerate,
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final interfaces = await (enumerate ?? _defaultEnumerate)().timeout(timeout);
    return (
      interfaceCount: interfaces.length,
      hasNonLoopback: interfaces.any((i) => !i.isLoopback),
    );
  } on Object {
    return null; // 静默降级 — kernel 红线: 仅 return null, 无日志输出.
  }
}

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
