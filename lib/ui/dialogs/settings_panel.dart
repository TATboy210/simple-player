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
  int _previousIndex = 0;
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  // ── GeneralTab 延迟应用的 pending 值 ──
  late String _pendingLocale;
  late int _pendingThemeIndex;

  // ── 取消时恢复用的原始值 ──
  late String _originalLocale;
  late int _originalThemeIndex;
  Map<String, String> _originalShortcuts = {};
  bool _depsInitialized = false;

  // ── 重置计数器 — 用于 ValueKey 强制 tab 重建 ──
  int _eqResetCounter = 0;
  int _shortcutsResetCounter = 0;
  int _perfResetCounter = 0;

  /// 可重置的 tab 索引集合（跳过 Audio=2, About=5）
  static const _resettableTabIndices = {0, 1, 3, 4, 6};

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

  // ── 重置功能 ──

  /// 显示毛玻璃风格的重置确认对话框
  ///
  /// 返回 true 表示用户确认重置，false 表示取消。
  Future<bool> _showResetConfirmDialog(
    String title,
    List<String> items,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: GlassTier.normal.blurFilter,
        child: AlertDialog(
          backgroundColor: Tokens.bgGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            side: const BorderSide(color: Tokens.borderHighlight),
          ),
          title: Text(title, style: const TextStyle(color: Tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Text(
                    '• $item',
                    style: const TextStyle(color: Tokens.textSecondary),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Tokens.danger),
              child: Text(l10n.confirmReset),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// 执行指定 tab 的重置逻辑
  ///
  /// General(0): 延迟应用 locale/theme 默认值
  /// Equalizer(1): 清除 EQ 滤镜
  /// Video(3): 重置所有视频处理状态
  /// Shortcuts(4): 清除自定义快捷键绑定
  /// Performance(6): 持久化默认性能设置
  void _resetTab(int index) {
    switch (index) {
      case 0:
        // General: 延迟应用 — 设置 pending 值为默认值，不直接调用 Service
        setState(() {
          _pendingLocale = 'zh';
          _pendingThemeIndex = 0;
        });
      case 1:
        // Equalizer: 清除 EQ 滤镜，tab 通过 Key 变化重建 _selectedIndex=0
        widget.engine.setEqualizer('');
        setState(() => _eqResetCounter++);
      case 3:
        // Video: service.resetAll() 重置状态并自动持久化
        widget.videoProcessing?.resetAll();
      case 4:
        // Shortcuts: 清除自定义绑定 + 持久化空 map
        widget.onShortcutsChanged?.call({});
        SettingsStore.saveShortcuts({});
        setState(() => _shortcutsResetCounter++);
      case 6:
        // Performance: 持久化默认值（true/true），tab 通过 Key 变化重建
        SettingsStore.saveD3d11SyncEnabled(true);
        SettingsStore.saveHardwareDecoding(true);
        setState(() => _perfResetCounter++);
    }
  }

  /// 返回指定 tab 重置时将影响的设置项名称列表（用于确认对话框展示）
  List<String> _tabResetItems(int index) {
    return switch (index) {
      0 => ['语言', '主题'],
      1 => ['均衡器预设'],
      3 => ['亮度', '对比度', '饱和度', '色调', '旋转', '宽高比', '去隔行'],
      4 => ['自定义快捷键绑定'],
      6 => ['D3D11 CPU 同步', '硬件解码'],
      _ => [],
    };
  }

  /// 返回指定 tab 的显示名称（用于确认对话框标题）
  String _tabName(int index, AppLocalizations l10n) {
    return switch (index) {
      0 => l10n.generalTab,
      1 => l10n.equalizer,
      3 => l10n.videoTab,
      4 => l10n.shortcutsTab,
      6 => l10n.performanceTab,
      _ => '',
    };
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
                              onSelect: (i) => setState(() {
                                _previousIndex = _selectedIndex;
                                _selectedIndex = i;
                              }),
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
                                    milliseconds: Tokens.durationSlide,
                                  ),
                                  // 滑动方向：前进(→)从右侧滑入，后退(←)从左侧滑入
                                  transitionBuilder: (child, animation) {
                                    final isForward =
                                        _selectedIndex >= _previousIndex;
                                    final offsetTween = Tween<Offset>(
                                      begin: Offset(
                                        isForward ? 0.3 : -0.3,
                                        0,
                                      ),
                                      end: Offset.zero,
                                    );
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: animation.drive(
                                          offsetTween.chain(
                                            CurveTween(
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
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

  /// tab 调用此方法请求重置 — 显示确认对话框，确认后执行重置
  Future<void> _onTabResetRequested(int index) async {
    final l10n = AppLocalizations.of(context);
    final title = l10n.resetConfirmTitle(_tabName(index, l10n));
    final items = _tabResetItems(index);
    final confirmed = await _showResetConfirmDialog(title, items);
    if (confirmed && mounted) {
      _resetTab(index);
    }
  }

  Widget _buildTab(int index) {
    return switch (index) {
      0 => GeneralTab(
        key: const ValueKey(0),
        currentLocale: _pendingLocale,
        currentThemeIndex: _pendingThemeIndex,
        onLocaleChanged: (code) => setState(() => _pendingLocale = code),
        onThemeChanged: (idx) => setState(() => _pendingThemeIndex = idx),
        onReset: () => _onTabResetRequested(0),
      ),
      1 => EqualizerTab(
        key: ValueKey('eq-$_eqResetCounter'),
        engine: widget.engine,
        onReset: () => _onTabResetRequested(1),
      ),
      2 => AudioTab(key: const ValueKey(2), engine: widget.engine),
      3 => VideoTab(
        key: const ValueKey(3),
        videoProcessing: widget.videoProcessing,
        onReset: () => _onTabResetRequested(3),
      ),
      4 => ShortcutsTab(
        key: ValueKey('sc-$_shortcutsResetCounter'),
        onShortcutsChanged: widget.onShortcutsChanged,
        onReset: () => _onTabResetRequested(4),
      ),
      5 => const AboutTab(key: ValueKey(5)),
      6 => PerformanceTab(
        key: ValueKey('perf-$_perfResetCounter'),
        engine: widget.engine,
        onReset: () => _onTabResetRequested(6),
      ),
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
        children: [
          // 重置按钮 — 仅在可重置的 tab 显示
          if (_resettableTabIndices.contains(_selectedIndex))
            TextButton(
              onPressed: () => _onTabResetRequested(_selectedIndex),
              child: Text(
                l10n.resetToDefaults,
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
          const Spacer(),
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

/// 底部操作按钮 — hover 缩放 + press 缩放 + primary 蓝色辉光
///
/// 交互反馈模式与 GlassButton 一致：
/// - hover → scale 1.02（Tokens.hoverScale）
/// - press → scale 0.98（Tokens.pressScale）
/// - primary 按钮额外添加 accent BoxShadow 辉光
class _BottomButton extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _BottomButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends State<_BottomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationFast),
      lowerBound: Tokens.pressScale,
      upperBound: Tokens.hoverScale,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    _scaleController.animateTo(hovering ? Tokens.hoverScale : 1.0);
  }

  void _onTapDown(TapDownDetails _) {
    _scaleController.value = Tokens.pressScale;
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    // primary 按钮带 accent 蓝色辉光
    final boxShadow = widget.primary
        ? [
            BoxShadow(
              color: Tokens.accent.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: -2,
            ),
          ]
        : null;

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spXs,
      ),
      decoration: BoxDecoration(
        color: widget.primary ? Tokens.accent : Colors.transparent,
        border: Border.all(
          color:
              widget.primary ? Tokens.accent : Tokens.borderHighlight,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        boxShadow: boxShadow,
      ),
      child: Text(
        widget.label,
        style: TextStyle(
          color: widget.primary ? Colors.white : Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
          fontWeight:
              widget.primary ? Tokens.weightMedium : Tokens.weightRegular,
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () => _scaleController.animateTo(1.0),
        hoverColor: Tokens.bgHover,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        splashFactory: NoSplash.splashFactory,
        child: content,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: ScaleTransition(scale: _scaleAnim, child: button),
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
