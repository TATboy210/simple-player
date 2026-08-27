import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/app_dialog.dart';
import '../../theme/tokens.dart';
import 'about_content.dart';

/// 设置窗口 — 左右结构壳：左侧分区导航，右侧分区内容。
///
/// 本轮不做实际设置功能：「通用 / 视频 / 音频」三个入口为灰显占位，
/// 唯一真实内容页是右侧的 [AboutContent]（关于）。未来接入真实分区时
/// 将对应 [_NavEntry] 置 enabled 并提供内容 builder 即可，布局无需重写。
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
      width: 620,
      height: 440,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsNav(l10n: l10n),
          // 左右分区的细分隔线 — 复用边框高亮 token 保持玻璃体系一致。
          Container(width: 1, color: Tokens.borderHighlight),
          const Expanded(child: AboutContent()),
        ],
      ),
    );
  }
}

/// 左侧竖排分区导航 — 「关于」外均为占位灰显项。
class _SettingsNav extends StatelessWidget {
  final AppLocalizations l10n;
  const _SettingsNav({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 占位分区 — 未来功能落点，暂不可交互（Avoid captive UI：无伪交互）。
          _NavEntry(icon: Icons.tune, label: l10n.generalTab),
          _NavEntry(icon: Icons.smart_display_outlined, label: l10n.videoTab),
          _NavEntry(icon: Icons.graphic_eq, label: l10n.audioTab),
          _NavEntry(
            icon: Icons.info_outline,
            label: l10n.aboutTab,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

/// 导航条目 — 图标 + 文字的横排行。
///
/// 默认（占位态）：38% 不透明度 + IgnorePointer，明确传达不可点击；
/// [enabled] 时以 bgHover 圆角底色高亮当前所在分区。
class _NavEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;

  const _NavEntry({
    required this.icon,
    required this.label,
    this.enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          margin: const EdgeInsets.only(bottom: Tokens.spXs),
          decoration: BoxDecoration(
            color: enabled ? Tokens.bgHover : null,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spSm,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? Tokens.accent : Tokens.textPrimary,
              ),
              const SizedBox(width: Tokens.spSm),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
