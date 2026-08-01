import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../kernel/engine/media_engine.dart';
import '../../kernel/services/playback_controller.dart';
import 'keyboard_handler.dart';
import 'shortcuts_help_dialog.dart';

/// 构造播放器键盘处理器 — 绑定 20+ 快捷键到 engine/controller.
///
/// F 键全屏: setMode 设 intent+mode + videoKey.toggleFullscreen 实际全屏 (方案 B).
/// 单用 toggleFullscreen: SC_MAXIMIZE→onWindowMaximize 覆盖 mode=maximized;
/// 单用 setMode 直调 fullscreen_window: GUI 失效 (方案 A 弃). 两者配合 + 守卫.
///
/// [isFullscreen] 由调用方 (AnimatedBuilder 内) 每次重建时传入,
/// 保证 onExitFullscreen 闭包捕获的是最新全屏状态.
/// [child] 通常是 Scaffold — KeyboardHandler 包裹它使焦点冒泡可达.
KeyboardHandler buildPlayerKeyboardActions({
  required MediaEngine engine,
  required PlaybackController controller,
  required WindowBridge windowService,
  required Map<String, String> customBindings,
  required GlobalKey<VideoState> videoKey,
  required bool isFullscreen,
  required BuildContext context,
  required Widget child,
  VoidCallback? onOpenFile,
}) {
  return KeyboardHandler(
    customBindings: customBindings,
    onPlayPause: () => engine.togglePlayPause(),
    onSeekBackward: () => _seek(engine, -5000),
    onSeekForward: () => _seek(engine, 5000),
    onVolumeUp: () => engine.setVolume(engine.volume.value + 0.05),
    onVolumeDown: () => engine.setVolume(engine.volume.value - 0.05),
    onToggleMute: () => engine.setMute(!engine.isMuted.value),
    onPrevious: () => controller.playPrevious(),
    onNext: () => controller.playNext(),
    onOpenFile: onOpenFile,
    onToggleSubtitle: () {
      engine.toggleSubtitle();
      // 录制字幕开关偏好 — S 键切换后记录新状态 (-1=关闭, 0+=轨道索引)
      final active = engine.activeSubtitleTracks;
      final newIndex = active.isEmpty ? -1 : active.first;
      controller.trackPreferenceService?.recordSubtitleTrack(newIndex);
    },
    onShowHelp: () => _showShortcutsHelp(context),
    onSubtitleDelayForward: () {
      final delay = engine.subtitleDelay;
      engine.setSubtitleDelay(delay + 500);
      // 录制字幕延迟偏好 — 跨会话恢复
      controller.trackPreferenceService?.recordSubtitleDelay(delay + 500);
    },
    onSubtitleDelayBackward: () {
      final delay = engine.subtitleDelay;
      engine.setSubtitleDelay(delay - 500);
      controller.trackPreferenceService?.recordSubtitleDelay(delay - 500);
    },
    onMediaPlayPause: () => engine.togglePlayPause(),
    onMediaNext: () => controller.playNext(),
    onMediaPrevious: () => controller.playPrevious(),
    // 方案 B: setMode 设 intent+mode (守卫 onWindowMaximize 同步 mode=fullscreen),
    // videoKey.toggleFullscreen 走 media_kit 原生全屏 (已验证可用).
    // 单用 toggleFullscreen: SC_MAXIMIZE→onWindowMaximize 覆盖 mode=maximized;
    // 单用 setMode 直调 fullscreen_window: GUI 失效 (方案 A 弃). 两者配合 + 守卫.
    onToggleFullscreen: () {
      final entering = !isFullscreen;
      windowService.setMode(
        entering ? WindowMode.fullscreen : WindowMode.windowed,
      );
      videoKey.currentState?.toggleFullscreen();
    },
    onExitFullscreen: () {
      if (isFullscreen) {
        windowService.setMode(WindowMode.windowed);
        videoKey.currentState?.toggleFullscreen();
      }
    },
    child: child,
  );
}

/// 相对 seek ±[deltaMs], clamp 到 [0, duration].
void _seek(MediaEngine engine, int deltaMs) {
  final target = engine.position.value + deltaMs;
  engine.seekTo(target.clamp(0, engine.duration.value));
}

/// 弹出快捷键帮助对话框.
void _showShortcutsHelp(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const ShortcutsHelpDialog(),
  );
}
