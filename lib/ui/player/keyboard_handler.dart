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
  ('N', l10n.shortcutNext),
  ('P', l10n.shortcutPrevious),
  ('O', l10n.shortcutOpenFile),
  ('S', l10n.shortcutSubtitle),
  ('] / [', l10n.shortcutSubtitleDelay),
  ('F1 / ?', l10n.shortcutHelp),
  ('媒体键', l10n.shortcutMediaKeys),
];

/// 键盘快捷键包装器 — 支持自定义绑定
///
/// Space → 播放/暂停 | ← → 后退/前进 5s | ↑ ↓ → 音量 ±5%
/// M → 静音 | N/P → 上/下一首
/// O → 打开文件 | S → 字幕开关 | ESC → 退出全屏
/// ]/[ → 字幕延迟 ± | F1 → 帮助
/// MediaPlayPause/MediaTrackNext/MediaTrackPrevious → 媒体键
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleSubtitle;
  final VoidCallback? onExitFullscreen;
  final VoidCallback? onShowHelp;
  final VoidCallback? onSubtitleDelayForward;
  final VoidCallback? onSubtitleDelayBackward;
  final VoidCallback? onMediaPlayPause;
  final VoidCallback? onMediaNext;
  final VoidCallback? onMediaPrevious;
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
    this.onPrevious,
    this.onNext,
    this.onOpenFile,
    this.onToggleSubtitle,
    this.onExitFullscreen,
    this.onShowHelp,
    this.onSubtitleDelayForward,
    this.onSubtitleDelayBackward,
    this.onMediaPlayPause,
    this.onMediaNext,
    this.onMediaPrevious,
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
    if (_keyMatches(key, 'next', LogicalKeyboardKey.keyN)) {
      onNext?.call();
      return KeyEventResult.handled;
    }
    if (_keyMatches(key, 'previous', LogicalKeyboardKey.keyP)) {
      onPrevious?.call();
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
      DebugExporter.saveToFile().then((path) {
        if (path != null) {
          developer.log('Debug data saved to: $path', name: 'Debug');
        }
      });
      return KeyEventResult.handled;
    }

    // FEAT-06: Media keys (always hardcoded, not customizable)
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      onMediaPlayPause?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      onMediaNext?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      onMediaPrevious?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
