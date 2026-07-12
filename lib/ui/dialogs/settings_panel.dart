import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/services/locale_service.dart';
import '../../kernel/services/theme_service.dart';
import '../../features/player/services/video_processing_service.dart';
import '../shared/glass_container.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'settings/_settings_nav_item.dart';
import 'settings/about_tab.dart';
import 'settings/audio_tab.dart';
import 'settings/equalizer_tab.dart';
import 'settings/general_tab.dart';
import 'settings/shortcuts_tab.dart';
import 'settings/video_tab.dart';
import 'settings/settings_tab_performance.dart';

/// Settings panel — draggable dialog with sidebar navigation and OK/Cancel/Apply.
///
/// Sidebar navigation pattern: 7 tabs mapped by index via [_Sidebar] → [_buildTab].
/// Tabs: General(0), Equalizer(1), Audio(2), Video(3), Shortcuts(4), About(5), Performance(6).
///
/// Locale and theme changes are deferred until dialog close (avoid MaterialApp rebuild
/// losing dialog state). GeneralTab receives pending values; ShortcutsTab notifies via
/// callback, restoring originals on cancel.
class SettingsPanel extends StatefulWidget {
  final EngineState engine;
  final VideoProcessingService? videoProcessing;
  final ValueChanged<Map<String, String>>? onShortcutsChanged;

  const SettingsPanel({
    super.key,
    required this.engine,
    this.videoProcessing,
    this.onShortcutsChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  int _selectedIndex = 0;
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  // ── GeneralTab 延迟应用的 pending 值 ──
  late String _pendingLocale;
  late int _pendingThemeIndex;

  // ── 取消时恢复用的原始值 ──
  late String _originalLocale;
  late int _originalThemeIndex;
  Map<String, String> _originalShortcuts = {};
  bool _depsInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadOriginalShortcuts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsInitialized) return;
    _depsInitialized = true;
    final current = Theme.of(context).colorScheme.primary;
    const accents = ThemeService.accents;
    final idx = accents.indexWhere((c) => c == current);
    _pendingThemeIndex = idx >= 0 ? idx : 0;
    _originalThemeIndex = _pendingThemeIndex;

    _pendingLocale = Localizations.localeOf(context).languageCode;
    _originalLocale = _pendingLocale;
  }

  Future<void> _loadOriginalShortcuts() async {
    _originalShortcuts = await SettingsStore.loadShortcuts();
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// 应用语言和主题变更（在对话框关闭后调用，避免 MaterialApp 重建丢失对话框状态）
  void _commitChanges() {
    if (_pendingLocale != _originalLocale) {
      LocaleService.I.setLocale(_pendingLocale);
    }
    if (_pendingThemeIndex != _originalThemeIndex) {
      ThemeService.I.setTheme(_pendingThemeIndex);
    }
  }

  void _cancel() {
    // 恢复语言/主题到打开 dialog 时的值
    if (_pendingLocale != _originalLocale) {
      LocaleService.I.setLocale(_originalLocale);
    }
    if (_pendingThemeIndex != _originalThemeIndex) {
      ThemeService.I.setTheme(_originalThemeIndex);
    }
    // 恢复快捷键
    widget.onShortcutsChanged?.call(_originalShortcuts);
    SettingsStore.saveShortcuts(_originalShortcuts);
    Navigator.of(context).pop();
  }

  void _ok() {
    _commitChanges();
    Navigator.of(context).pop();
  }

  void _apply() {
    _commitChanges();
    // 更新原始值以便后续取消时以当前值为基准
    _originalLocale = _pendingLocale;
    _originalThemeIndex = _pendingThemeIndex;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        // 半透明背景遮罩 — 点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: _cancel,
            child: Container(color: Colors.black54),
          ),
        ),
        // 可拖拽面板 — ValueListenableBuilder 隔离拖拽 rebuild
        ValueListenableBuilder<Offset>(
          valueListenable: _offset,
          builder: (context, offset, panel) =>
              Transform.translate(offset: offset, child: panel),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 80, top: 48),
              child: GlassContainer(
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                child: SizedBox(
                  width: 600,
                  height: 480,
                  child: Column(
                    children: [
                      // 标题栏 — 拖拽区域
                      GestureDetector(
                        onPanStart: (_) {},
                        onPanUpdate: (d) {
                          _offset.value += d.delta;
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Tokens.spMd,
                          ),
                          color: Tokens.bgGlass,
                          child: Row(
                            children: [
                              Text(
                                l10n.settings,
                                style: const TextStyle(
                                  color: Tokens.textPrimary,
                                  fontSize: Tokens.fontBody,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: Tokens.textTertiary,
                              ),
                              const SizedBox(width: Tokens.spSm),
                              InkWell(
                                onTap: _cancel,
                                borderRadius: BorderRadius.circular(
                                  Tokens.radiusBtn,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Tokens.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Tokens.borderHighlight),
                      // 内容区：侧边栏 + 内容
                      Expanded(
                        child: Row(
                          children: [
                            _Sidebar(
                              selectedIndex: _selectedIndex,
                              l10n: l10n,
                              onSelect: (i) =>
                                  setState(() => _selectedIndex = i),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Tokens.borderHighlight,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(Tokens.spMd),
                                child: AnimatedSwitcher(
                                  duration: const Duration(
                                    milliseconds: Tokens.durationFast,
                                  ),
                                  child: _buildTab(_selectedIndex),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Tokens.borderHighlight),
                      // 底部按钮行
                      _buildBottomBar(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index) {
    return switch (index) {
      0 => GeneralTab(
        key: const ValueKey(0),
        currentLocale: _pendingLocale,
        currentThemeIndex: _pendingThemeIndex,
        onLocaleChanged: (code) => setState(() => _pendingLocale = code),
        onThemeChanged: (idx) => setState(() => _pendingThemeIndex = idx),
      ),
      1 => EqualizerTab(key: const ValueKey(1), engine: widget.engine),
      2 => AudioTab(key: const ValueKey(2), engine: widget.engine),
      3 => VideoTab(
        key: const ValueKey(3),
        videoProcessing: widget.videoProcessing,
      ),
      4 => ShortcutsTab(
        key: const ValueKey(4),
        onShortcutsChanged: widget.onShortcutsChanged,
      ),
      5 => const AboutTab(key: ValueKey(5)),
      6 => PerformanceTab(key: const ValueKey(6), engine: widget.engine),
      _ => GeneralTab(
        key: const ValueKey(0),
        currentLocale: _pendingLocale,
        currentThemeIndex: _pendingThemeIndex,
      ),
    };
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      color: Tokens.bgGlass,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _BottomButton(label: l10n.ok, primary: true, onTap: _ok),
          const SizedBox(width: Tokens.spSm),
          _BottomButton(label: l10n.cancel, onTap: _cancel),
          const SizedBox(width: Tokens.spSm),
          _BottomButton(label: l10n.apply, onTap: _apply),
        ],
      ),
    );
  }
}

// ── 底部按钮 ──

class _BottomButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _BottomButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: primary ? Tokens.accent : Colors.transparent,
          border: Border.all(
            color: primary ? Tokens.accent : Tokens.borderHighlight,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? Colors.white : Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
            fontWeight: primary ? Tokens.weightMedium : Tokens.weightRegular,
          ),
        ),
      ),
    );
  }
}

// ── 侧边栏导航 ──

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final AppLocalizations l10n;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.l10n,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Tokens.spSm),
        children: [
          SettingsNavItem(
            icon: Icons.tune,
            label: l10n.generalTab,
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          SettingsNavItem(
            icon: Icons.equalizer,
            label: l10n.equalizer,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          SettingsNavItem(
            icon: Icons.headphones,
            label: l10n.audioTrack,
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          SettingsNavItem(
            icon: Icons.videocam,
            label: l10n.videoProcessing,
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
          ),
          SettingsNavItem(
            icon: Icons.keyboard,
            label: l10n.shortcutsTab,
            selected: selectedIndex == 4,
            onTap: () => onSelect(4),
          ),
          SettingsNavItem(
            icon: Icons.info_outline,
            label: l10n.aboutTab,
            selected: selectedIndex == 5,
            onTap: () => onSelect(5),
          ),
          SettingsNavItem(
            icon: Icons.speed,
            label: l10n.performanceTab,
            selected: selectedIndex == 6,
            onTap: () => onSelect(6),
          ),
        ],
      ),
    );
  }
}
