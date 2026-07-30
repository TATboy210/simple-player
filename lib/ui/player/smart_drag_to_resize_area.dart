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
    // 始终用 DragToResizeArea 保持 Widget 类型一致;
    // enabled=false 时套 IgnorePointer 禁用拖拽但不改类型 (canUpdate 仍 true).
    final dragArea = DragToResizeArea(child: child);
    if (enabled) return dragArea;
    return IgnorePointer(child: dragArea);
  }
}
