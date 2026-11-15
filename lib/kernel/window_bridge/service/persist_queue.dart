import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../diagnostics/kernel_logger.dart';
import '../../persistence/window_persistence.dart';
import '../window_bridge.dart';
import 'normal_bounds_tracker.dart';
import 'window_geometry.dart';

/// 几何落盘串行队列（契约 8）。
///
/// 存「最近一次普通窗口矩形 + 最大化标志」：最大化不覆盖还原尺寸（仅
/// windowed 态现场采样）；尺寸 clamp 到最小值；全屏期不落盘（防把显示器
/// 尺寸写进偏好）。串行队列防并发整文件重写交错。
class PersistQueue {
  PersistQueue({
    required this.persistence,
    required this.bounds,
    required this.mode,
    required this.isAlwaysOnTop,
    required this.supportsWindowPositioning,
    required this.isDisposed,
  });

  final WindowPersistence persistence;
  final NormalBoundsTracker bounds;
  final ValueListenable<WindowMode> mode;
  final ValueListenable<bool> isAlwaysOnTop;

  /// Wayland 下 x/y 恒 0，落盘位置无意义 — 显式 null 交由 compositor 定位。
  final bool supportsWindowPositioning;

  final bool Function() isDisposed;

  Future<void> _queue = Future<void>.value();

  /// 当前排队中的落盘 — 测试等待落盘完成用，避免依赖真实延时。
  Future<void> get pending => _queue;

  /// 排队一次落盘 — 串行防交错。
  void schedule() {
    // 串行链必须原子追加; async/await 改写会在 await 点引入交错窗口.
    // ignore: prefer-async-await
    _queue = _queue.then((_) => persistNow());
    unawaited(_queue);
  }

  /// 等待已排队落盘完成（关窗序列调用，防与关窗落盘交错写同一份快照）。
  Future<void> drain() => _queue;

  /// 立即落盘。全屏期跳过；普通窗口态以现值为准（拖动结束可能没有
  /// resize 信号），其余态沿用最近一次普通矩形。
  Future<void> persistNow() async {
    if (isDisposed() || mode.value.isFullscreen) return;
    if (mode.value.isWindowed) bounds.sample();
    final normal = bounds.value;
    try {
      await persistence.save(
        PersistedWindowState(
          size: Size(
            math.max(normal.width, minimumWindowSize.width),
            math.max(normal.height, minimumWindowSize.height),
          ),
          position: supportsWindowPositioning ? normal.topLeft : null,
          alwaysOnTop: isAlwaysOnTop.value,
          isMaximized: mode.value.isMaximized,
        ),
      );
    } on Exception catch (error, stackTrace) {
      KernelLogger.I.w('[PersistQueue] $error\n$stackTrace');
    }
  }
}
