import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../diagnostics/kernel_logger.dart';

/// 全局热键服务 — 窗口失焦时仍可响应媒体键.
///
/// Global hotkey service — responds to media keys even when window is unfocused.
///
/// Registers 3 system-level hotkeys:
/// - MediaPlayPause → play/pause
/// - MediaTrackNext → next track
/// - MediaTrackPrevious → previous track
///
/// Complements KeyboardHandler: latter handles window-internal shortcuts;
/// this service handles system-level media keys (window-external).
class GlobalHotkeyService {
  VoidCallback? _onPlayPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;

  /// 注册全部全局热键（回调可为 null，后续通过 [bind] 绑定）.
  ///
  /// Registers all global hotkeys. Callbacks may be null (bind later via [bind]).
  /// Each hotkey is individually try-caught — single failure doesn't block others.
  /// Silent degradation on failure (window-internal shortcuts still work).
  Future<void> registerAll() async {
    try {
      await hotKeyManager.unregisterAll();
    } on Exception catch (e) {
      KernelLoggerImpl.I.e('GlobalHotkeyService: unregisterAll failed', error: e);
    }

    final hotkeys = [
      (
        HotKey(
          key: PhysicalKeyboardKey.mediaPlayPause,
          scope: HotKeyScope.system,
        ),
        'MediaPlayPause',
      ),
      (
        HotKey(
          key: PhysicalKeyboardKey.mediaTrackNext,
          scope: HotKeyScope.system,
        ),
        'MediaTrackNext',
      ),
      (
        HotKey(
          key: PhysicalKeyboardKey.mediaTrackPrevious,
          scope: HotKeyScope.system,
        ),
        'MediaTrackPrevious',
      ),
    ];

    var registered = 0;
    for (final (hotkey, name) in hotkeys) {
      try {
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (_) => switch (name) {
            'MediaPlayPause' => _onPlayPause?.call(),
            'MediaTrackNext' => _onNext?.call(),
            'MediaTrackPrevious' => _onPrevious?.call(),
            _ => null,
          },
        );
        registered++;
      } on Exception catch (e) {
        KernelLoggerImpl.I.e('GlobalHotkeyService: $name registration failed', error: e);
      }
    }

    KernelLoggerImpl.I.i('GlobalHotkeyService: registered $registered/3 media hotkeys');
  }

  /// 绑定播放控制回调 — 引擎/控制器就绪后调用.
  ///
  /// Binds playback control callbacks — called after engine/controller ready.
  void bind({
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
  }) {
    _onPlayPause = onPlayPause;
    _onNext = onNext;
    _onPrevious = onPrevious;
    KernelLoggerImpl.I.d('GlobalHotkeyService: callbacks bound');
  }

  /// 注销全部全局热键.
  ///
  /// Unregisters all global hotkeys.
  Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
    KernelLoggerImpl.I.d('GlobalHotkeyService: unregistered all');
  }
}
