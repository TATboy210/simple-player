import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../diagnostics/kernel_logger.dart';

/// 全局热键服务 — 窗口失焦时仍可响应媒体键
///
/// 注册 3 个系统级热键：
/// - MediaPlayPause → 播放/暂停
/// - MediaTrackNext → 下一首
/// - MediaTrackPrevious → 上一首
///
/// 与 KeyboardHandler 互补：后者处理窗口内快捷键，
/// 本服务处理窗口外（系统级）媒体键。
class GlobalHotkeyService {
  VoidCallback? _onPlayPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;

  /// 注册全部全局热键（回调可为 null，后续通过 [bind] 绑定）
  ///
  /// 每个热键单独 try-catch：单个注册失败不影响其他。
  /// 失败静默降级（窗口内快捷键仍可用）。
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

  /// 绑定播放控制回调 — 引擎/控制器就绪后调用
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

  /// 注销全部全局热键
  Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
    KernelLoggerImpl.I.d('GlobalHotkeyService: unregistered all');
  }
}
