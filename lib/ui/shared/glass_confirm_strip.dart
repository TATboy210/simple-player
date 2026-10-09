import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass_container.dart' show GlassButton;
import 'secondary_surface.dart';

/// 删除确认内容 — owner supplies choice callbacks, no Navigator or root barrier.
/// Only the message scrolls; both actions stay reachable in short panels.
class GlassConfirmStrip extends StatelessWidget {
  const GlassConfirmStrip({
    super.key,
    required this.message,
    required this.cancelLabel,
    required this.confirmTooltip,
    required this.onCancel,
    required this.onConfirm,
    this.cancelFocus,
    this.confirmFocus,
    this.confirmIcon = Icons.delete,
  });

  final String message;
  final String cancelLabel;
  final String confirmTooltip;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// 取消按钮的外部焦点节点 — 与 [confirmFocus] 同构; 由宿主提供以便
  /// 键盘焦点陷阱 (tab-trap) 在两按钮间回绕。
  final FocusNode? cancelFocus;

  /// 确认按钮的外部焦点节点 — 可选, 与 [cancelFocus] 完全同构.
  /// Confirm button's externally-owned focus node — mirrors [cancelFocus].
  /// 传入后宿主可把 Tab 回绕落点锚定在确认按钮上 (焦点封闭域); 默认
  /// null 时行为与无此参数完全一致 (按钮内部自建节点), 既有调用点向后
  /// 兼容。
  final FocusNode? confirmFocus;
  final IconData confirmIcon;

  @override
  Widget build(BuildContext context) => SecondarySurface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
        ),
        const SizedBox(height: Tokens.spSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              size: Tokens.spXl,
              color: Tokens.danger,
            ),
            const Spacer(),
            GlassButton.iconOnly(
              icon: Icons.close,
              tooltip: cancelLabel,
              autofocus: true,
              focusNode: cancelFocus,
              onPressed: onCancel,
            ),
            const SizedBox(width: Tokens.spXs),
            GlassButton.iconOnly(
              icon: confirmIcon,
              tooltip: confirmTooltip,
              color: Tokens.danger,
              focusNode: confirmFocus,
              onPressed: onConfirm,
            ),
          ],
        ),
      ],
    ),
  );
}
