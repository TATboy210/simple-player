import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 包装 [DragToResizeArea]，增加 enabled 属性.
///
/// 解决 canUpdate 问题: 全屏/窗口模式切换时, 始终返回同一 Widget 类型,
/// 避免 Element 销毁重建导致 Texture 子树丢失 (黑帧闪烁根因之一).
/// [enabled]=false 时用 [IgnorePointer] 禁用拖拽交互 (全屏场景).
class SmartDragToResizeArea extends StatelessWidget {
  const SmartDragToResizeArea({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // 常驻两层祖先，只更新 ignoring 属性；全屏切换因此可沿原 Element 链
    // 更新配置，而不会因插入或移除 IgnorePointer 扰动 Texture 子树身份。
    return IgnorePointer(
      ignoring: !enabled,
      child: DragToResizeArea(child: child),
    );
  }
}
