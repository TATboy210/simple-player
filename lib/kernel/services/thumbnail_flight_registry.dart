import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// in-flight flight — 一次具体的解帧执行（P-Thumb v1.3.2 §10.3 / A.3）
///
/// Key 是值身份，Flight 是一次具体执行 — 同 key 允许不同代次的 Flight
/// 短暂共存；旧代完成后靠 epoch 判定丧失 cache commit 权（§19.7）。
final class ThumbnailFlight {
  ThumbnailFlight({
    required this.path,
    required this.cacheKey,
    required this.globalEpoch,
    required this.pathEpoch,
    required this.isForce,
  });

  /// normalize 后的源文件路径
  final String path;

  /// identity cacheKey — 注册表 join 键
  final String cacheKey;

  /// 创建时刻捕获的 global epoch 快照（§19.4）
  final int globalEpoch;

  /// 创建时刻捕获的 path epoch 快照
  final int pathEpoch;

  /// H5：force 请求只 join force flight — 双击 retry 不产生第二个并发解帧
  final bool isForce;

  final Completer<ImageProvider?> _completer = Completer<ImageProvider?>();

  Future<ImageProvider?> get future => _completer.future;

  /// completer 的语义化包装 — Completer 二次 complete 抛 StateError，
  /// 有意为之：重复 complete 是编程 bug，必须暴露（I11 同源）。
  void complete(ImageProvider? provider) => _completer.complete(provider);
}

/// in-flight 注册表 + epoch 失效内核（P-Thumb v1.3.2 A.15 / §19）
///
/// identical 守卫清理与 epoch 判定收敛为单点（§44.5 维护性封装）。
/// 单线程 UI isolate 使用，不加锁。
///
/// 生命周期语义：
/// - `register` → join 入口生效
/// - `remove`   → identical 守卫，只删自己那一代（§18.5 — F4）
/// - `evictPath`→ pathEpoch++ 使该 path 全部在飞 flight 失效
/// - `clear`    → globalEpoch++ O(1) 失效全部（§19.2）
/// - `isCurrent`→ global+path 双 epoch 判定（§19.5）— R7 检查点唯一入口
///
/// **pathEpoch 条目永不按条目回收**（§19.9/X14）：任何清理都会重置
/// epoch 序列，使 gate 队列中 pathEpoch=0 的 stale flight 复活。
/// 接受有界泄漏：增长上界 = evict 调用次数，clear() 统一清空。
final class ThumbnailFlightRegistry {
  int _globalEpoch = 0;
  final Map<String, int> _pathEpoch = {};
  final Map<String, ThumbnailFlight> _byKey = {};
  final Map<String, Set<ThumbnailFlight>> _byPath = {};

  /// 当前占用该 key 的 flight（join 入口）
  ThumbnailFlight? forKey(String cacheKey) => _byKey[cacheKey];

  /// 该 path 上在飞的 force flight — 双击 retry 的 join 入口（H5/F6）。
  /// retry 若直接重复 evict 会把前一个 force flight 打成 stale，
  /// 产生第二次解帧 — 必须先查在飞 force 再决定 evict。
  ThumbnailFlight? forceFlightFor(String path) {
    for (final flight in _byPath[path] ?? const <ThumbnailFlight>[]) {
      if (flight.isForce) return flight;
    }
    return null;
  }

  /// 创建 flight — 捕获当前 epoch 快照（§19.4）
  ThumbnailFlight create({
    required String path,
    required String cacheKey,
    required bool isForce,
  }) {
    return ThumbnailFlight(
      path: path,
      cacheKey: cacheKey,
      globalEpoch: _globalEpoch,
      pathEpoch: _pathEpoch[path] ?? 0,
      isForce: isForce,
    );
  }

  /// 注册 flight — 使后续同 key 请求可 join
  void register(ThumbnailFlight flight) {
    _byKey[flight.cacheKey] = flight;
    _byPath.putIfAbsent(flight.path, () => <ThumbnailFlight>{}).add(flight);
  }

  /// flight 完成清理 — identical 守卫：Key 相同 ≠ Flight 相同（§2.1/§18.5）
  ///
  /// 旧代 flight 完成时注册表键可能已属于新代 — 此时不删，
  /// 新代 flight 的 join 通道不受旧代完成的影响（F4）。
  void remove(ThumbnailFlight flight) {
    if (identical(_byKey[flight.cacheKey], flight)) {
      _byKey.remove(flight.cacheKey);
    }
    final set = _byPath[flight.path];
    if (set != null) {
      set.remove(flight);
      if (set.isEmpty) _byPath.remove(flight.path);
    }
    // 不清 _pathEpoch — 见类注释 §19.9 决议
  }

  /// evict(path) — pathEpoch++ + 该 path 全部在飞 flight 出 join 表（A.9）
  void evictPath(String path) {
    _pathEpoch[path] = (_pathEpoch[path] ?? 0) + 1;

    final flights = _byPath[path]?.toList(growable: false);
    if (flights == null) return;
    for (final flight in flights) {
      if (identical(_byKey[flight.cacheKey], flight)) {
        _byKey.remove(flight.cacheKey);
      }
    }
  }

  /// clearCache — O(1) 失效全部 flight（A.10）
  ///
  /// 旧 Future 仍可完成，但 globalEpoch 已变 → isCurrent 全 false。
  void clear() {
    _globalEpoch++;
    _byKey.clear();
    _byPath.clear();
    _pathEpoch.clear();
  }

  /// epoch 判定唯一入口（§19.5）— R7 要求所有 commit 前检查点复用此方法
  bool isCurrent(ThumbnailFlight flight) =>
      flight.globalEpoch == _globalEpoch &&
      flight.pathEpoch == (_pathEpoch[flight.path] ?? 0);

  /// 在飞 flight 数（测试观测）
  @visibleForTesting
  int get activeCount => _byKey.length;
}
