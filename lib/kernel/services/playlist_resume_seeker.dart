/// 断点续播补 seek — 挂起请求 + 低位锁存 + 超时兜底 (从 PlaylistCoordinator 拆出).
///
/// Deferred resume-seek: `seek` only waits for player init, not for the new
/// file to finish loading, so an immediate seek after open/jump is lost.
/// This helper parks the request until the engine signals "new item started".
library;

import 'dart:async';

/// 补 seek 的 position 低位锁存区 — 新条目开始播放时首个 position 事件
/// 必然低于此值; 超出即视为旧条目残留事件, 继续等待.
const int _resumeSeekLatchMs = 2000;

/// 挂起 seek 超时兜底 — 媒体加载极慢 (网络流/损坏文件) 时低位信号可能
/// 迟迟不到; 超时放弃, 防悬挂 (断点丢失可接受, 播放不受阻).
const Duration _resumeTimeout = Duration(seconds: 5);

/// 断点续播补 seek 调度器.
///
/// 不持有引擎: 触发时由 [onPosition]/[onDuration] **返回**待 seek 的位置,
/// 调用方负责执行 (保持本类纯逻辑、可脱离引擎测试, 也免去回调循环依赖).
class PlaylistResumeSeeker {
  /// 待补的 seek 位置 — null = 无挂起请求.
  int? _pendingMs;
  Timer? _timeout;

  /// 是否有挂起请求 (测试/诊断用).
  bool get hasPending => _pendingMs != null;

  /// 挂起一次 seek, 重新计时超时窗口.
  void arm(int resumeMs) {
    _pendingMs = resumeMs;
    _timeout?.cancel();
    _timeout = Timer(_resumeTimeout, () => _pendingMs = null);
  }

  /// position 事件 — 返回应立即 seek 的位置, 无则 null.
  ///
  /// **必须传引擎活值而非粘性值**: 上曲遗留的高位粘性值会让低位信号
  /// 永不满足, 续播静默失效. 一次性消费, seek 自身产生的 position 事件
  /// 不会重复触发.
  int? onPosition({required int liveMs, required int engineDurationMs}) {
    if (liveMs < _resumeSeekLatchMs && engineDurationMs > 0) return _take();
    return null;
  }

  /// duration 事件 — 首次有效即补齐 (装载场景); 返回应 seek 的位置或 null.
  int? onDuration(int liveMs) => liveMs > 0 ? _take() : null;

  /// 取出并清除挂起请求 (一次性消费).
  int? _take() {
    final pending = _pendingMs;
    if (pending == null) return null;
    _pendingMs = null;
    _timeout?.cancel();
    return pending;
  }

  /// 取消超时计时器并丢弃挂起请求.
  void dispose() {
    _timeout?.cancel();
    _pendingMs = null;
  }
}
