import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/utils/debug_exporter.dart';
import '../../l10n/app_localizations.dart';

/// 快捷键定义 — KeyboardHandler 和帮助对话框共享的单一数据源
///
/// 每个条目: (按键显示文本, 功能描述)
/// 新增快捷键时必须同时更新此列表和 KeyboardHandler._handleKeyEvent。
List<(String, String)> shortcutDefinitions(AppLocalizations l10n) => [
  ('Space', l10n.shortcutPlayPause),
  ('← / →', l10n.shortcutSeek),
  ('↑ / ↓', l10n.shortcutVolume),
  ('ESC', l10n.shortcutExitFullscreen),
  ('M', l10n.shortcutMute),
  ('O', l10n.shortcutOpenFile),
  ('S', l10n.shortcutSubtitle),
  ('] / [', l10n.shortcutSubtitleDelay),
  ('F1 / ?', l10n.shortcutHelp),
  ('媒体键', l10n.shortcutMediaKeys),
];

/// 键盘快捷键包装器 — 支持自定义绑定
///
/// Space → 播放/暂停 | ← → 后退/前进 5s | ↑ ↓ → 音量 ±5%
/// M → 静音 | O → 打开文件 | S → 字幕开关 | ESC → 退出全屏
/// ]/[ → 字幕延迟 ± | F1 → 帮助 | MediaPlayPause → 媒体播放键
///
/// [customBindings] 覆盖默认按键映射 (action → LogicalKeyboardKey.keyName)
class KeyboardHandler extends StatelessWidget {
  final Widget child;
  final Map<String, String> customBindings;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onToggleMute;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleSubtitle;
  final VoidCallback? onExitFullscreen;
  final VoidCallback? onShowHelp;
  final VoidCallback? onSubtitleDelayForward;
  final VoidCallback? onSubtitleDelayBackward;
  final VoidCallback? onMediaPlayPause;
  const KeyboardHandler({
    super.key,
    required this.child,
    this.customBindings = const {},
    this.onPlayPause,
    this.onSeekBackward,
    this.onSeekForward,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onToggleFullscreen,
    this.onToggleMute,
    this.onOpenFile,
    this.onToggleSubtitle,
    this.onExitFullscreen,
    this.onShowHelp,
    this.onSubtitleDelayForward,
    this.onSubtitleDelayBackward,
    this.onMediaPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: true, onKeyEvent: _handleKeyEvent, child: child);
  }

  /// 检查按键是否匹配指定动作（优先自定义绑定，否则使用默认按键）
  /// customBindings 存储 keyId 字符串
  bool _keyMatches(
    LogicalKeyboardKey key,
    String action,
    LogicalKeyboardKey defaultKey,
  ) {
    if (customBindings.isEmpty) return key == defaultKey;
    final bound = customBindings[action];
    if (bound == null) return key == defaultKey;
    return key.keyId.toString() == bound;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 不拦截文本输入框的按键事件
    final focused = FocusManager.instance.primaryFocus;
    final context = focused?.context;
    if (context != null) {
      final widget = context.widget;
      if (widget is EditableText) return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_keyMatches(key, 'playPause', LogicalKeyboardKey.space)) {
      onPlayPause?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'seekBackward', LogicalKeyboardKey.arrowLeft)) {
      onSeekBackward?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'seekForward', LogicalKeyboardKey.arrowRight)) {
      onSeekForward?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'volumeUp', LogicalKeyboardKey.arrowUp)) {
      onVolumeUp?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'volumeDown', LogicalKeyboardKey.arrowDown)) {
      onVolumeDown?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'mute', LogicalKeyboardKey.keyM)) {
      onToggleMute?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'openFile', LogicalKeyboardKey.keyO)) {
      onOpenFile?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'subtitle', LogicalKeyboardKey.keyS)) {
      onToggleSubtitle?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'exitFullscreen', LogicalKeyboardKey.escape)) {
      onExitFullscreen?.call();
      return KeyEventResult.handled;
    }
    // F 键切换全屏 — callback (player_keyboard_actions.onToggleFullscreen) 已修症状④:
    // enter 用 videoKey.enterFullscreen; exit 直接 rootNavigator.maybePop
    // (窗口态 key 的 toggleFullscreen/exitFullscreen 受 isFullscreen 守卫失效).
    // TODO: 补 shortcutDefinitions + l10n.shortcutFullscreen 以在帮助面板显示.
    if (_keyMatches(key, 'toggleFullscreen', LogicalKeyboardKey.keyF)) {
      onToggleFullscreen?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'help', LogicalKeyboardKey.f1) ||
        (key == LogicalKeyboardKey.slash && event.character == '?')) {
      onShowHelp?.call();
      return KeyEventResult.handled;
    }

    // FEAT-04: Subtitle timing
    if (_keyMatches(
      key,
      'subtitleDelayForward',
      LogicalKeyboardKey.bracketRight,
    )) {
      onSubtitleDelayForward?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(
      key,
      'subtitleDelayBackward',
      LogicalKeyboardKey.bracketLeft,
    )) {
      onSubtitleDelayBackward?.call();
      return KeyEventResult.handled;
    }

    // 调试快捷键: Ctrl+Shift+D 导出全部调试数据
    if (kDebugMode &&
        key == LogicalKeyboardKey.keyD &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      unawaited(_exportDebugData());
      return KeyEventResult.handled;
    }

    // 系统媒体播放键固定映射，不受自定义快捷键配置影响。
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      onMediaPlayPause?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 导出调试数据到文件 (Ctrl+Shift+D)。
  ///
  /// 提取为 async 方法以用 await 替代 .then 链 (DCM prefer-async-await)。
  Future<void> _exportDebugData() async {
    final path = await DebugExporter.saveToFile();
    if (path != null) {
      developer.log('Debug data saved to: $path', name: 'Debug');
    }
  }
}
