import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../kernel/persistence/settings_store.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// 快捷键自定义 tab — 显示/录制/重置快捷键绑定
///
/// [onShortcutsChanged] 在每次绑定变更时回调，由 SettingsPanel 负责持久化。
class ShortcutsTab extends StatefulWidget {
  final ValueChanged<Map<String, String>>? onShortcutsChanged;

  const ShortcutsTab({super.key, this.onShortcutsChanged});

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

  void _resetAll() {
    setState(() => _customBindings = {});
    widget.onShortcutsChanged?.call({});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final defs = _shortcutDefs(l10n);

    return Column(
      children: [
        // 快捷键列表
        Expanded(
          child: KeyboardListener(
            focusNode: _keyListenerFocus,
            autofocus: _recordingAction != null,
            onKeyEvent: _onKeyPressed,
            child: SettingsCard(
              title: l10n.shortcutsTab,
              icon: Icons.keyboard,
              margin: EdgeInsets.zero,
              children: [
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
        // 重置按钮
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: Tokens.spSm),
            child: InkWell(
              onTap: _resetAll,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spMd,
                  vertical: Tokens.spXs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Tokens.borderHighlight, width: 1),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: Text(
                  l10n.resetShortcuts,
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
