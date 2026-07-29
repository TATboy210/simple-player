import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../kernel/persistence/settings_store.dart';
import '../../../kernel/services/input_mode_detector.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/glass_container.dart';
import '../../shared/animated_section_list.dart';
import '../../shared/section_header.dart';
import '../../shared/settings_card.dart'; // keep for SettingActionRow export

/// 快捷键自定义 tab — 显示/录制/重置快捷键绑定
///
/// [onShortcutsChanged] 在每次绑定变更时回调，由 SettingsPanelController
/// 负责持久化（通过 PendingSettingsState 延迟应用）。
class ShortcutsTab extends StatefulWidget {
  final ValueChanged<Map<String, String>>? onShortcutsChanged;
  final VoidCallback? onReset;

  const ShortcutsTab({super.key, this.onShortcutsChanged, this.onReset});

  @override
  State<ShortcutsTab> createState() => _ShortcutsTabState();
}

class _ShortcutsTabState extends State<ShortcutsTab> {
  /// 当前自定义绑定 (action → keyName)
  Map<String, String> _customBindings = {};

  /// 正在录制的动作 ID，null 表示未在录制
  String? _recordingAction;

  final _keyListenerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadBindings();
  }

  @override
  void dispose() {
    _keyListenerFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBindings() async {
    final bindings = await SettingsStore.loadShortcuts();
    if (mounted) setState(() => _customBindings = bindings);
  }

  String _currentKeyFor(String action, LogicalKeyboardKey defaultKey) {
    return _customBindings[action] ?? defaultKey.keyId.toString();
  }

  void _startRecording(String action) {
    setState(() => _recordingAction = action);
  }

  void _cancelRecording() {
    setState(() => _recordingAction = null);
  }

  void _onKeyPressed(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_recordingAction == null) return;

    final keyName = event.logicalKey.keyId.toString();

    // ESC 取消录制
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _recordingAction = null);
      return;
    }

    // 检测冲突：同一按键已绑定到其他动作
    final conflict = _customBindings.entries.firstWhere(
      (e) => e.value == keyName && e.key != _recordingAction,
      orElse: () => const MapEntry('', ''),
    );

    setState(() {
      if (conflict.key.isNotEmpty) {
        // 解除冲突方的绑定
        _customBindings.remove(conflict.key);
      }
      _customBindings[_recordingAction!] = keyName;
      _recordingAction = null;
    });

    widget.onShortcutsChanged?.call(Map.unmodifiable(_customBindings));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final defs = _shortcutDefs(l10n);

    // AnimatedSectionList 内部返回 Column，自身处理布局
    // 不使用 Expanded — Scaffold.body 不是 Flex 容器
    // The new mode-toggle row extends this discrete option list beyond the
    // fixed test viewport, so retain every shortcut by making the tab scroll.
    return SingleChildScrollView(
      child: AnimatedSectionList(
        children: [
          // 快捷键列表
          KeyboardListener(
            focusNode: _keyListenerFocus,
            autofocus: _recordingAction != null,
            onKeyEvent: _onKeyPressed,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spLg,
                vertical: Tokens.spMd,
              ),
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: l10n.shortcutsTab, icon: Icons.keyboard),
                  // 输入模式切换 (NAV-02) — pointer-only chip，不抢 KeyboardListener 焦点 (D-09)。
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.spSm),
                    child: _InputModeToggle(),
                  ),
                  for (final def in defs)
                    SettingActionRow(
                      label: def.label,
                      valueText: friendlyKeyName(
                        _currentKeyFor(def.action, def.defaultKey),
                      ),
                      isActive: _recordingAction == def.action,
                      activeText: l10n.pressKeyToBind,
                      onAction: () => _startRecording(def.action),
                      onDeactivate: _recordingAction == def.action
                          ? _cancelRecording
                          : null,
                    ),
                ],
              ),
            ),
          ),
          // 重置按钮 — 底部左侧（通过确认对话框）
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: Tokens.spSm),
              child: TextButton(
                onPressed: widget.onReset,
                child: Text(
                  l10n.resetToDefaults,
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 输入模式切换 chip (NAV-02) ──

/// 输入模式切换 chip —— pointer-only，不抢 KeyboardListener 焦点 (D-09)。
///
/// 显示当前 [InputModeDetector.preference] (keyboard/gamepad/auto)，点击循环
/// 切换。用 [GestureDetector] 而非 [InkWell] —— 纯指针交互无 focus 语义，
/// 保证快捷键录制时 [KeyboardListener] 独占键盘焦点 (D-09)。
class _InputModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InputMode>(
      valueListenable: InputModeDetector.instance.preference,
      builder: (context, mode, _) {
        final (label, icon) = _modeDisplay(mode);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => InputModeDetector.instance.toggle(_nextMode(mode)),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spMd,
              vertical: Tokens.spXs,
            ),
            decoration: BoxDecoration(
              color: Tokens.bgGlass,
              borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              border: Border.all(color: Tokens.borderHighlight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: Tokens.fontCaption,
                  color: Tokens.textSecondary,
                ),
                const SizedBox(width: Tokens.spXs),
                Text(
                  label,
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 当前偏好 → (显示文本, 图标)。
  (String, IconData) _modeDisplay(InputMode mode) => switch (mode) {
    InputMode.keyboard => ('Keyboard', Icons.keyboard),
    InputMode.gamepad => ('Gamepad', Icons.gamepad),
    InputMode.auto => ('Auto', Icons.autorenew),
  };

  /// 循环顺序：keyboard → gamepad → auto → keyboard。
  /// 基于 preference 三态（含 auto），非 effectiveMode。
  InputMode _nextMode(InputMode current) => switch (current) {
    InputMode.keyboard => InputMode.gamepad,
    InputMode.gamepad => InputMode.auto,
    InputMode.auto => InputMode.keyboard,
  };
}

// ── 数据模型 ──

class _ShortcutDef {
  final String action;
  final LogicalKeyboardKey defaultKey;
  final String label;
  const _ShortcutDef(this.action, this.defaultKey, this.label);
}

List<_ShortcutDef> _shortcutDefs(AppLocalizations l10n) => [
  _ShortcutDef('playPause', LogicalKeyboardKey.space, l10n.shortcutPlayPause),
  _ShortcutDef('seekBackward', LogicalKeyboardKey.arrowLeft, l10n.shortcutSeek),
  _ShortcutDef('seekForward', LogicalKeyboardKey.arrowRight, l10n.shortcutSeek),
  _ShortcutDef('volumeUp', LogicalKeyboardKey.arrowUp, l10n.shortcutVolume),
  _ShortcutDef('volumeDown', LogicalKeyboardKey.arrowDown, l10n.shortcutVolume),
  _ShortcutDef('fullscreen', LogicalKeyboardKey.keyF, l10n.shortcutFullscreen),
  _ShortcutDef(
    'exitFullscreen',
    LogicalKeyboardKey.escape,
    l10n.shortcutExitFullscreen,
  ),
  _ShortcutDef('mute', LogicalKeyboardKey.keyM, l10n.shortcutMute),
  _ShortcutDef('next', LogicalKeyboardKey.keyN, l10n.shortcutNext),
  _ShortcutDef('previous', LogicalKeyboardKey.keyP, l10n.shortcutPrevious),
  _ShortcutDef('openFile', LogicalKeyboardKey.keyO, l10n.shortcutOpenFile),
  _ShortcutDef('subtitle', LogicalKeyboardKey.keyS, l10n.shortcutSubtitle),
  _ShortcutDef(
    'subtitleDelayForward',
    LogicalKeyboardKey.bracketRight,
    l10n.shortcutSubtitleDelay,
  ),
  _ShortcutDef(
    'subtitleDelayBackward',
    LogicalKeyboardKey.bracketLeft,
    l10n.shortcutSubtitleDelay,
  ),
  _ShortcutDef('help', LogicalKeyboardKey.f1, l10n.shortcutHelp),
];

// ── 按键显示名转换 ──

/// 将 keyId 字符串转为友好显示文本
String friendlyKeyName(String keyIdStr) {
  final id = int.tryParse(keyIdStr);
  if (id == null) return keyIdStr;
  final key = LogicalKeyboardKey.findKeyByKeyId(id);
  if (key == null) return keyIdStr;

  // 特殊键的友好名称
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.escape) return 'ESC';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  if (key == LogicalKeyboardKey.delete) return 'Delete';
  if (key == LogicalKeyboardKey.f1) return 'F1';
  if (key == LogicalKeyboardKey.f2) return 'F2';
  if (key == LogicalKeyboardKey.f3) return 'F3';
  if (key == LogicalKeyboardKey.f4) return 'F4';
  if (key == LogicalKeyboardKey.f5) return 'F5';
  if (key == LogicalKeyboardKey.f6) return 'F6';
  if (key == LogicalKeyboardKey.f7) return 'F7';
  if (key == LogicalKeyboardKey.f8) return 'F8';
  if (key == LogicalKeyboardKey.f9) return 'F9';
  if (key == LogicalKeyboardKey.f10) return 'F10';
  if (key == LogicalKeyboardKey.f11) return 'F11';
  if (key == LogicalKeyboardKey.f12) return 'F12';
  if (key == LogicalKeyboardKey.bracketLeft) return '[';
  if (key == LogicalKeyboardKey.bracketRight) return ']';

  // 字母键
  final label = key.keyLabel;
  if (label.isNotEmpty) return label.toUpperCase();

  return keyIdStr;
}

// ── 行组件 ──
