import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'control_bar_decoration.dart';
import 'glass_blur_layer.dart';
import 'glass_container.dart' show GlassButton, GlassTier;

/// 长条玻璃确认条 — 删除类操作的统一确认浮层 (v0.0.7).
///
/// Horizontal glass confirm strip for destructive actions. 视觉与交互
/// 完全对齐控制栏：[ControlBarDecoration.playing] 4-shadow 装饰 +
/// [GlassTier.normal] 毛玻璃 + [GlassButton.iconOnly] 小方块按钮
/// (36×36, hover 微亮/按下变暗同款反馈)。
///
/// 长条形态 (非居中大对话框)：浮现于视口中下 (控制栏上方)，警示图标 +
/// 正文 + 取消/确认两枚小方块按钮，点遮罩即取消 (多退路, 避免强制式 UI).
class GlassConfirmStrip extends StatelessWidget {
  /// 弹出确认条 — 确认返回 true，取消/点遮罩返回 false.
  ///
  /// - [message] 正文文案（单条移除与批量删除共用同一正式文案模板）.
  /// - [confirmIcon] 确认按钮图标 (默认删除).
  /// - [confirmTooltip] 确认按钮 tooltip (文案即动作语义).
  static Future<bool> show(
    BuildContext context, {
    required String message,
    IconData confirmIcon = Icons.delete,
    required String confirmTooltip,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // 点遮罩 = 取消 (非强制式 UI)
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // 长条位置 — 视口中下 (控制栏上方), 与控制栏/面板同屏共存.
          alignment: const Alignment(0, 0.62),
          child: GlassConfirmStrip._(
            message: message,
            cancelLabel: l10n.cancel,
            confirmLabel: l10n.batchDeleteConfirmAction,
            confirmIcon: confirmIcon,
            confirmTooltip: confirmTooltip,
          ),
        );
      },
    );
    return result ?? false;
  }

  const GlassConfirmStrip._({
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.confirmTooltip,
  });

  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final String confirmTooltip;

  static final _stripRadius = BorderRadius.circular(Tokens.controlBarRadius);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ControlBarDecoration.playing(borderRadius: _stripRadius),
      // v0.0.8.2 D1: 瞬态小件降档 thin(8.0) — 长条确认条面积小,
      // 叠加 black26 遮罩后模糊层次肉眼近无差.
      child: GlassBlurLayer(
        borderRadius: _stripRadius,
        filter: GlassTier.thin.blurFilter,
        child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spMd,
              vertical: Tokens.spSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 警示图标 — danger 红, 语义先行.
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 22,
                  color: Tokens.danger,
                ),
                const SizedBox(width: Tokens.spSm),
                // 正文 — Expanded 自适应宽度, 两行封顶.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Tokens.textPrimary,
                      fontSize: Tokens.fontCaption,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.spMd),
                // 取消 — 控制栏同款小方块按钮.
                GlassButton.iconOnly(
                  icon: Icons.close,
                  tooltip: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: Tokens.spXs),
                // 确认删除 — danger 红图标, 同款小方块交互.
                GlassButton.iconOnly(
                  icon: confirmIcon,
                  tooltip: confirmTooltip,
                  color: Tokens.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
