part of 'settings_panel.dart';

/// 面板标题行 — "设置" + 返回按钮（仅 L1 出现） + 关闭按钮。
///
/// 无 accent 竖条（v0.0.8 用户裁决）；返回按钮出现在"设置"右侧，
/// 淡入淡出 + 恒定占位防标题跳动；字号/按钮与播放列表标题行同规格。
class _PanelHeader extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final bool showBack;
  final VoidCallback? onPromote;
  final Animation<double> backOpacity;

  const _PanelHeader({
    required this.l10n,
    required this.onBack,
    required this.onClose,
    required this.showBack,
    this.onPromote,
    required this.backOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.spMd,
        Tokens.spMd,
        Tokens.spSm,
        Tokens.spSm,
      ),
      child: Row(
        children: [
          Text(
            l10n.settings,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontBody,
              fontWeight: Tokens.weightSemiBold,
            ),
          ),
          const SizedBox(width: Tokens.spSm),
          // 返回按钮 — 仅 L1 出现（层级动画驱动淡入淡出，恒占位防跳）.
          FadeTransition(
            opacity: backOpacity,
            child: IgnorePointer(
              ignoring: !showBack,
              child: Opacity(
                opacity: showBack ? 1.0 : 0.0,
                child: GlassButton.iconOnly(
                  icon: Icons.arrow_back,
                  tooltip: l10n.back,
                  onPressed: onBack,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (onPromote != null)
            GlassButton.iconOnly(
              icon: Icons.flip_to_front,
              tooltip: l10n.moveToCenter,
              onPressed: onPromote,
            ),
          GlassButton.iconOnly(
            icon: Icons.close,
            tooltip: l10n.close,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// 竖排分区 tag — 图标 + 类别名 + 条目枚举摘要小字（三行，左对齐）。
///
/// hover/pressed 色阶沿用旧 _NavEntry 语言（hover 渐现 bgHover、pressed
/// 按下沉降色）；选中态 = bgHover 常驻底 + accent 图标/文字，**无竖条
/// 指示**（v0.0.8 裁决）。灰显分区 38% 不透明 + IgnorePointer。
class _SettingsTabChip extends StatefulWidget {
  final _SettingsTab tab;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SettingsTabChip({
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_SettingsTabChip> createState() => _SettingsTabChipState();
}

class _SettingsTabChipState extends State<_SettingsTabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = widget.selected;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.enabled ? widget.onTap : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              // Key 供测试断言选中底色（以枚举名区分分区）.
              key: ValueKey('settings-tab-${widget.tab.name}'),
              duration: const Duration(milliseconds: Tokens.durationFast),
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spSm,
                vertical: Tokens.spSm,
              ),
              decoration: BoxDecoration(
                // 选中恒亮 / 悬停瞬态同底色（_NavEntry 同款语义）。
                color: (selected || _hovered) && widget.enabled
                    ? Tokens.bgHover
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _tabIcon(widget.tab),
                        size: 18,
                        color: selected && widget.enabled
                            ? Tokens.accent
                            : Tokens.textPrimary,
                      ),
                      const SizedBox(width: Tokens.spSm),
                      Text(
                        _tabLabel(l10n),
                        style: TextStyle(
                          color: selected && widget.enabled
                              ? Tokens.accent
                              : Tokens.textPrimary,
                          fontSize: Tokens.fontBody,
                          fontWeight: Tokens.weightSemiBold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.spXs),
                  // 摘要跑马灯 — 空间足够静止全显, 不足从右向左循环滚动;
                  // 滚动空间随 chip 宽（面板宽）响应联动.
                  LoopMarqueeText(
                    text: _tabSummary(l10n),
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _tabIcon(_SettingsTab tab) => switch (tab) {
    _SettingsTab.general => Icons.tune,
    _SettingsTab.video => Icons.smart_display_outlined,
    _SettingsTab.audio => Icons.graphic_eq,
    _SettingsTab.about => Icons.info_outline,
  };

  String _tabLabel(AppLocalizations l10n) => switch (widget.tab) {
    _SettingsTab.general => l10n.generalTab,
    _SettingsTab.video => l10n.videoTab,
    _SettingsTab.audio => l10n.audioTab,
    _SettingsTab.about => l10n.aboutTab,
  };

  String _tabSummary(AppLocalizations l10n) => switch (widget.tab) {
    _SettingsTab.general => l10n.settingsSummaryGeneral,
    _SettingsTab.video => l10n.settingsSummaryVideo,
    _SettingsTab.audio => l10n.settingsSummaryAudio,
    _SettingsTab.about => l10n.settingsSummaryAbout,
  };
}
