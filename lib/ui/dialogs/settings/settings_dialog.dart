import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/app_dialog.dart';
import '../../theme/tokens.dart';
import 'about_content.dart';
import 'general_settings_content.dart';

/// 设置分区 —— 左侧导航的四个条目（视频/音频仍为占位）。
enum _SettingsTab { general, video, audio, about }

/// 设置窗口 — 左右结构壳：左侧分区导航，右侧分区内容。
///
/// 「通用 / 关于」可交互并携带选中高亮（per-dialog StatefulWidget 状态），
/// 「视频 / 音频」保持灰显占位（Avoid captive UI：无伪交互）。内容区按选中
/// 分区切换 [GeneralSettingsContent] / [AboutContent]；未来接入新分区时在
/// [_SettingsTab] 增值并将对应 [_NavEntry] 置 enabled 提供内容分支即可。
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  /// 以默认 navigator 弹出设置窗口；全屏 route 上层同样正常浮起。
  ///
  /// Fire-and-forget 调用方可不等待返回值（返回值供需要 await 的测试使用）。
  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const SettingsDialog());

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  /// 当前选中分区 —— 初始「关于」（向后兼容现状：直接打开设置看到 About）。
  _SettingsTab _selected = _SettingsTab.about;

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
          _SettingsNav(
            l10n: l10n,
            selected: _selected,
            onSelect: (tab) => setState(() => _selected = tab),
          ),
          // 左右分区的细分隔线 — 复用边框高亮 token 保持玻璃体系一致。
          Container(width: 1, color: Tokens.borderHighlight),
          Expanded(
            child: switch (_selected) {
              _SettingsTab.general => const GeneralSettingsContent(),
              _SettingsTab.about => const AboutContent(),
              // 视频/音频分支不可达 —— 灰显占位项不会进入选中态；
              // 防御分支返回空视图而非伪造内容。
              _SettingsTab.video ||
              _SettingsTab.audio =>
                const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

/// 左侧竖排分区导航 — 「通用 / 关于」可交互，「视频 / 音频」灰显占位。
class _SettingsNav extends StatelessWidget {
  final AppLocalizations l10n;
  final _SettingsTab selected;
  final ValueChanged<_SettingsTab> onSelect;

  const _SettingsNav({
    required this.l10n,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavEntry(
            tab: _SettingsTab.general,
            icon: Icons.tune,
            label: l10n.generalTab,
            enabled: true,
            selected: selected == _SettingsTab.general,
            onTap: () => onSelect(_SettingsTab.general),
          ),
          // 占位分区 — 未来功能落点，暂不可交互（Avoid captive UI：无伪交互）。
          _NavEntry(
            tab: _SettingsTab.video,
            icon: Icons.smart_display_outlined,
            label: l10n.videoTab,
          ),
          _NavEntry(
            tab: _SettingsTab.audio,
            icon: Icons.graphic_eq,
            label: l10n.audioTab,
          ),
          _NavEntry(
            tab: _SettingsTab.about,
            icon: Icons.info_outline,
            label: l10n.aboutTab,
            enabled: true,
            selected: selected == _SettingsTab.about,
            onTap: () => onSelect(_SettingsTab.about),
          ),
        ],
      ),
    );
  }
}

/// 导航条目 — 图标 + 文字的横排行。
///
/// 灰显占位（enabled=false）：38% 不透明度 + IgnorePointer，明确传达不可点击；
/// enabled 且未选中：完整不透明 + 无底色（可点击等待选中）；
/// [selected]：bgHover 圆角底 + accent 图标/文字的持续高亮 —— 区别于 hover 的
/// 瞬态，选中态不随鼠标离开消失。
class _NavEntry extends StatelessWidget {
  final _SettingsTab tab;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  const _NavEntry({
    required this.tab,
    required this.icon,
    required this.label,
    this.enabled = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          onTap: onTap,
          // opaque 让行内空白区也可点击（桌面友好，无伪交互语义）。
          behavior: HitTestBehavior.opaque,
          child: Container(
            // Key 供测试断言选中高亮（以枚举名区分条目）。
            key: ValueKey('settings-nav-${tab.name}'),
            decoration: BoxDecoration(
              color: selected ? Tokens.bgHover : null,
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
                  color: selected ? Tokens.accent : Tokens.textPrimary,
                ),
                const SizedBox(width: Tokens.spSm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Tokens.accent : Tokens.textPrimary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
