import 'dart:ui';

import '../../diagnostics/kernel_logger.dart';
import '../../persistence/window_persistence.dart';
import '../port/native_window.dart';
import 'window_geometry.dart';

/// 隐藏态几何恢复（契约 5/10 + Wayland 降级）。
///
/// init 阶段窗口尚未亮（reveal 前），恢复引发的尺寸变化被契约 6 吞掉，
/// 不产生假会话/假落盘。返回 tracker 种子矩形（最近普通矩形初值）。
class GeometryRestore {
  const GeometryRestore({required this.supportsPositioning});

  /// 窗口定位语义是否可用（Wayland=false → 只应用尺寸，位置交 compositor）。
  final bool supportsPositioning;

  /// 恢复持久化几何，返回还原矩形跟踪器的种子值。
  ///
  /// 位置缺失、或不在任何显示器工作区内（上次的副屏已拔掉）时只应用尺寸
  /// 并居中，避免窗口出现在屏幕外找不回。
  Rect restore(NativeWindow window, PersistedWindowState persisted) {
    if (!supportsPositioning) {
      window.setSize(persisted.size);
      return window.bounds;
    }
    final rect = restoreBounds(
      position: persisted.position,
      size: persisted.size,
      workAreas: _workAreasOrEmpty(window),
    );
    if (rect != null) {
      window.bounds = rect;
      return rect;
    }
    if (persisted.position != null) {
      KernelLogger.I.w(
        '[GeometryRestore] persisted position off-screen — centering',
      );
    }
    window.setSize(persisted.size);
    window.center();
    return window.bounds;
  }

  /// 工作区查询失败视为「未知」— [isReachableOnAnyDisplay] 对空列表信任原值。
  List<Rect> _workAreasOrEmpty(NativeWindow window) {
    try {
      return window.workAreas;
    } on Exception catch (error, stackTrace) {
      KernelLogger.I.w(
        '[GeometryRestore] work area query failed: $error\n$stackTrace',
      );
      return const <Rect>[];
    }
  }
}
