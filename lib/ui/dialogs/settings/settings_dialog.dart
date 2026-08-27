import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/app_dialog.dart';
import '../../theme/tokens.dart';

/// 设置窗口 — 本轮仅 UI 壳：极简单页占位，不含任何实际功能。
///
/// 形态沿用 [AppDialog] 体系（同 media_info_dialog 的属性弹窗）；未来真实
/// 设置功能在此壳内逐项填充，壳的开合行为与视觉基调保持不变。
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  /// 以默认 navigator 弹出设置窗口；全屏 route 上层同样正常浮起。
  ///
  /// Fire-and-forget 调用方可不等待返回值（返回值供需要 await 的测试使用）。
  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const SettingsDialog());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.settings,
      width: 360,
      height: 240,
      // 极简单页占位 — 居中图标 + 一句说明，无任何可交互控件。
      content: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings_outlined,
              size: Tokens.dialogEmptyIconSize,
              color: Tokens.textSecondary,
            ),
            const SizedBox(height: Tokens.spLg),
            Text(
              l10n.settingsPlaceholder,
              style: const TextStyle(
                color: Tokens.textSecondary,
                fontSize: Tokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
