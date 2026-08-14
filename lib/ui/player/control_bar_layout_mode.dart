import '../theme/tokens.dart';

/// 控制栏根据父级实际宽度选择的两档布局模式。
///
/// 只影响控件呈现，不改变 [ControlBarViewModel] 回调，因此隐藏的操作仍可
/// 通过键盘快捷键使用。断点基于 LayoutBuilder 的约束，而不是设备类型。
enum ControlBarLayoutMode {
  normal,
  minimal;

  /// 从父级分配的宽度计算布局模式。
  static ControlBarLayoutMode fromWidth(double width) =>
      width >= Tokens.controlBarMinimalBreakpoint ? normal : minimal;

  /// 当前模式是否为最小布局。
  bool get isMinimal => this == minimal;

  /// 当前模式是否允许显示音量滑块、倍速和文件动作。
  bool get showsSecondaryActions => this == normal;

  /// 当前模式是否保留快退、快进和停止。
  bool get showsTransportActions => this == normal;
}
