import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// 快捷键定义 — KeyboardHandler 和帮助对话框共享的单一数据源
///
/// 每个条目: (按键显示文本, 功能描述)
/// 新增快捷键时必须同时更新此列表和 KeyboardHandler._handleKeyEvent。
List<(String, String)> shortcutDefinitions(AppLocalizations l10n) => [
      ('Space', l10n.shortcutPlayPause),
      ('← / →', l10n.shortcutSeek),
      ('↑ / ↓', l10n.shortcutVolume),
      ('F', l10n.shortcutFullscreen),
      ('ESC', l10n.shortcutExitFullscreen),
      ('M', l10n.shortcutMute),
      ('N', l10n.shortcutNext),
      ('P', l10n.shortcutPrevious),
      ('O', l10n.shortcutOpenFile),
      ('S', l10n.shortcutSubtitle),
      ('] / [', l10n.shortcutSubtitleDelay),
      ('F1 / ?', l10n.shortcutHelp),
      ('A', l10n.aspectRatio),
      ('媒体键', l10n.shortcutMediaKeys),
    ];

/// 键盘快捷键包装器 — 19 个快捷键
///
/// Space → 播放/暂停 | ← → 后退/前进 5s | ↑ ↓ → 音量 ±5%
/// F → 全屏 | M → 静音 | N/P → 上/下一首
/// O → 打开文件 | S → 字幕开关 | ESC → 退出全屏
/// ]/[ → 字幕延迟 ± | F1 → 帮助
/// MediaPlayPause/MediaTrackNext/MediaTrackPrevious → 媒体键
class KeyboardHandler extends StatelessWidget {
  final Widget child;
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
  final VoidCallback? onCycleAspectRatio;

  const KeyboardHandler({
    super.key,
    required this.child,
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
    this.onCycleAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: true, onKeyEvent: _handleKeyEvent, child: child);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 不拦截文本输入框的按键事件
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null && focused.context != null) {
      final widget = focused.context!.widget;
      if (widget is EditableText) return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      onPlayPause?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      onSeekBackward?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      onSeekForward?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      onVolumeUp?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      onVolumeDown?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      onToggleFullscreen?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      onToggleMute?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      onNext?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      onPrevious?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyO) {
      onOpenFile?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS) {
      onToggleSubtitle?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      onExitFullscreen?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f1 ||
        (key == LogicalKeyboardKey.slash && event.character == '?')) {
      onShowHelp?.call();
      return KeyEventResult.handled;
    }

    // FEAT-04: Subtitle timing
    if (key == LogicalKeyboardKey.bracketRight) {
      onSubtitleDelayForward?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft) {
      onSubtitleDelayBackward?.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyA) {
      onCycleAspectRatio?.call();
      return KeyEventResult.handled;
    }

    // FEAT-06: Media keys
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
