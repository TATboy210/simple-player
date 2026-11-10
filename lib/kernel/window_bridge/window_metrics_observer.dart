import 'package:flutter/widgets.dart';

/// 引擎指标观察者 — 拖拽会话的默认检测源（阶段一改，替代 nativeapi 逐步事件）。
///
/// Why：nativeapi 的 Moved/Resized 事件在窗口线程按步构建+投递，是拖拽"内容
/// 追边框"的主犯（取证见 docs/audit/resize-drag-ab-2026-11.md）。而
/// [WidgetsBindingObserver.didChangeMetrics] 由引擎在视图尺寸**实际变化**时
/// 送达（按帧率合并、走 Dart 侧管线），一次回调即可当作"几何有变"信号，
/// 会话细节（防抖/边沿/落盘）全部留在 [WindowService] 内。
///
/// 尺寸没变的 metrics 抖动（如仅 DPI 浮点扰动）通过比对 physicalSize 过滤。
class WindowMetricsObserver with WidgetsBindingObserver {
  /// [onGeometryChanged] 在每次**视图尺寸真实变化**后回调一次。
  /// [currentSize] 为测试 seam — 生产缺省读真实 platformDispatcher 首视图
  /// （测试 binding 的 setSurfaceSize 与 view.physicalSize 跨版本行为不稳，
  /// 去抖语义直接用注入尺寸源验证）。
  WindowMetricsObserver({
    required this.onGeometryChanged,
    Size Function()? currentSize,
  }) : _currentSize = currentSize ?? _viewPhysicalSize {
    _lastSize = _currentSize();
  }

  /// 会话检测回调 — 生产接线到 `WindowService.noteGeometryChanged`。
  final VoidCallback onGeometryChanged;

  /// 尺寸源（注入或真实视图）。
  final Size Function() _currentSize;

  /// 构造时快照的视图尺寸 — 只响应变化量，不响应首帧基线。
  late Size _lastSize;

  static Size _viewPhysicalSize() {
    // binding 未初始化会直接抛 — 挂载点在 runApp 之后，两处均已就绪，
    // 不做判空兜底（那会吞掉真实的接线错误）。
    return WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  }

  @override
  void didChangeMetrics() {
    final size = _currentSize();
    if (size == _lastSize) return;
    _lastSize = size;
    onGeometryChanged();
  }
}
