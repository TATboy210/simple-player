import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/services/locale_service.dart';
import '../../kernel/services/theme_service.dart';
import '../../kernel/utils/log.dart';
import '../../kernel/services/video_processing_service.dart';
import '../shared/glass_container.dart';
import '../shared/osd_overlay.dart';
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
  final WindowBridge windowService;

  const SettingsPanel({
    super.key,
    required this.engine,
    required this.windowService,
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
    // 监听全屏模式变化 — 进入/退出全屏时重置拖拽偏移 (D-09)
    widget.windowService.mode.addListener(_onModeChanged);
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
    widget.windowService.mode.removeListener(_onModeChanged);
    _offset.dispose();
    super.dispose();
  }

  /// 全屏模式变化时重置拖拽偏移 — 面板居中后偏移量无意义 (D-09)
  void _onModeChanged() {
    _offset.value = Offset.zero;
  }

  /// ESC 按键拦截 — 在全屏模式下关闭面板而非退出全屏 (D-04, D-12)
  ///
  /// 返回 [KeyEventResult.handled] 阻止事件传播到外层 KeyboardHandler。
  KeyEventResult _handleEscape(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  // ── Import / Export ──

  /// 导出所有设置为 JSON 文件 (D-05, D-13)
  ///
  /// 流程：file_picker 保存对话框 → SettingsStore.exportSettings → 写入文件
  /// 默认文件名含日期 `settings_YYYY-MM-DD.json`
  Future<void> _exportSettings() async {
    final l10n = AppLocalizations.of(context);
    // 生成带日期的默认文件名
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final defaultFileName = 'settings_$dateStr.json';

    final result = await FilePicker.saveFile(
      dialogTitle: l10n.exportSettings,
      fileName: defaultFileName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    // 用户取消选择
    if (result == null) return;

    try {
      final json = await SettingsStore.exportSettings();
      await File(result).writeAsString(json);
      // 导出成功 — OSD 提示
      if (mounted) {
        OsdService.I.show(l10n.exportSuccess);
      }
    } on FileSystemException catch (e) {
      // 磁盘满、权限不足等 I/O 错误 (D-13)
      log.e('Export failed: $e');
      if (mounted) {
        OsdService.I.show(l10n.exportError);
      }
    } on FormatException catch (e) {
      // JSON 序列化错误 (D-13)
      log.e('Export failed: $e');
      if (mounted) {
        OsdService.I.show(l10n.exportError);
      }
    }
  }

  /// 从 JSON 文件导入设置 (D-06, D-07, D-12, D-14, D-15)
  ///
  /// 流程：file_picker 打开对话框 → 读取文件 → SettingsStore.importSettings
  ///       → 成功则显示确认对话框，失败则显示错误对话框
  Future<void> _importSettings() async {
    final l10n = AppLocalizations.of(context);

    final result = await FilePicker.pickFiles(
      dialogTitle: l10n.importSettings,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    // 用户取消选择
    if (result == null || result.files.isEmpty) return;

    // 读取文件内容
    final String json;
    try {
      json = await File(result.files.first.path!).readAsString();
    } on FileSystemException catch (e) {
      // 文件读取失败 (D-12)
      log.e('Import file read failed: $e');
      if (mounted) {
        _showImportErrorDialog(l10n.importFileReadError(e.message));
      }
      return;
    }

    // 解析并验证 JSON
    final importResult = await SettingsStore.importSettings(json);

    if (!mounted) return;

    switch (importResult) {
      case ImportFailure(:final error):
        // 解析/验证失败 — 显示详细错误 (D-12)
        _showImportErrorDialog(l10n.importParseError(error));
      case ImportSuccess():
        // 解析成功 — 显示确认对话框 (D-09, D-10, D-11)
        _showImportConfirmDialog(importResult);
    }
  }

  /// 导入失败错误对话框 — 毛玻璃风格，显示详细错误信息 (D-12)
  void _showImportErrorDialog(String errorMessage) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: GlassTier.normal.blurFilter,
        child: AlertDialog(
          backgroundColor: Tokens.bgGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            side: const BorderSide(color: Tokens.borderHighlight),
          ),
          title: Text(l10n.importError(''), style: const TextStyle(color: Tokens.textPrimary)),
          content: Text(
            errorMessage,
            style: const TextStyle(color: Tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
  }

  /// 导入确认对话框 — 毛玻璃风格，显示将被覆盖的设置类别 (D-09, D-10, D-11)
  ///
  /// 确认后调用 [_onImportConfirmed] 立即应用所有设置。
  void _showImportConfirmDialog(ImportSuccess result) {
    final l10n = AppLocalizations.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: GlassTier.normal.blurFilter,
        child: AlertDialog(
          backgroundColor: Tokens.bgGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            side: const BorderSide(color: Tokens.borderHighlight),
          ),
          title: Text(
            l10n.importConfirmTitle,
            style: const TextStyle(color: Tokens.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.importConfirmMessage,
                style: const TextStyle(color: Tokens.textSecondary),
              ),
              const SizedBox(height: Tokens.spSm),
              Text(
                l10n.importConfirmCategories,
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                backgroundColor: Tokens.accent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.confirmReset),
            ),
          ],
        ),
      ),
    ).then((confirmed) {
      // 用户确认导入 — 立即应用所有设置 (D-14)
      if (confirmed == true && mounted) {
        _onImportConfirmed(result);
      }
    });
  }

  /// 导入确认后 — 立即应用设置，更新面板状态，保持面板打开 (D-14, D-15)
  ///
  /// - 通过 SettingsStore 持久化所有设置
  /// - 通过 LocaleService/ThemeService 立即更新 UI
  /// - 更新 _pendingLocale/_pendingThemeIndex 使面板反映新值
  /// - 不调用 Navigator.pop — 面板保持打开 (D-15)
  Future<void> _onImportConfirmed(ImportSuccess result) async {
    final l10n = AppLocalizations.of(context);
    // 持久化所有设置到 SharedPreferences
    await SettingsStore.applyImportedSettings(result);

    // 立即更新 locale/theme 服务 — UI 实时响应 (D-14)
    LocaleService.I.setLocale(result.locale);
    ThemeService.I.setTheme(result.themeIndex);

    // 更新面板内部 pending 值 — 使 GeneralTab 显示新导入的 locale/theme
    setState(() {
      _pendingLocale = result.locale;
      _pendingThemeIndex = result.themeIndex;
    });

    // OSD 成功提示
    if (mounted) {
      OsdService.I.show(l10n.importSuccess);
    }
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
    // PopScope 阻止 Navigator.maybePop — ESC 由 _handleEscape 统一处理 (D-04)
    return PopScope(
      canPop: false,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleEscape,
        child: Stack(
          children: [
            // 半透明背景遮罩 — 点击关闭 (D-07: Colors.black54 不变)
            Positioned.fill(
              child: GestureDetector(
                onTap: _cancel,
                child: Container(color: Colors.black54),
              ),
            ),
            // 全屏感知定位 — AnimatedAlign 在全屏时居中，窗口模式时左上角 (D-01, D-03, D-05, D-06, D-08)
            ValueListenableBuilder<WindowMode>(
              valueListenable: widget.windowService.mode,
              builder: (context, mode, _) {
                final isFullscreen = mode.isFullscreen;
                return AnimatedAlign(
                  alignment: isFullscreen
                      ? Alignment.center
                      : Alignment.topLeft,
                  duration: const Duration(
                    milliseconds: Tokens.durationSlide,
                  ),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: isFullscreen
                        ? EdgeInsets.zero
                        : const EdgeInsets.only(left: 80, top: 48),
                    // 拖拽偏移 — 在 AnimatedAlign 内部，偏移相对于对齐位置 (D-09)
                    child: ValueListenableBuilder<Offset>(
                      valueListenable: _offset,
                      builder: (context, offset, panel) =>
                          Transform.translate(offset: offset, child: panel),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(Tokens.radiusLg),
                        child: SizedBox(
                          width: 600,
                          height: 480,
                          child: Column(
                            children: [
                              // 标题栏 — 全屏时禁用拖拽 (D-06, D-11)
                              GestureDetector(
                                onPanStart: isFullscreen ? null : (_) {},
                                onPanUpdate: isFullscreen
                                    ? null
                                    : (d) {
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
                                      // 拖拽指示器 — 全屏时隐藏 (D-11)
                                      if (!isFullscreen) ...[
                                        const Icon(
                                          Icons.drag_indicator,
                                          size: 16,
                                          color: Tokens.textTertiary,
                                        ),
                                        const SizedBox(width: Tokens.spSm),
                                      ],
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
        ); // AnimatedAlign
        }, // builder
      ), // ValueListenableBuilder<WindowMode>
      ],
      ), // Stack
      ), // Focus
    ); // PopScope
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
          // Import/Export 按钮组
          _BottomButton(label: l10n.importSettings, onTap: _importSettings),
          const SizedBox(width: Tokens.spSm),
          _BottomButton(label: l10n.exportSettings, onTap: _exportSettings),
          // 竖线分隔符 — 区分 Import/Export 和 OK/Cancel/Apply
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
            child: Container(
              width: 1,
              height: 20,
              color: Tokens.borderHighlight,
            ),
          ),
          // OK/Cancel/Apply 按钮组
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
