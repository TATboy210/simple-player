/// 播放状态管理 — 恢复并持久化单文件播放器设置。
///
/// [PlaybackStateManager] 只管理跨会话有效的音量与静音设置；播放列表、
/// 历史、断点和播放模式已不属于 v1.8 单文件播放器运行时。
library;

import 'dart:async';

import '../diagnostics/kernel_logger.dart';
import '../persistence/settings_store.dart';
import 'playback_controller.dart';

final _log = KernelLogger.I;

/// 单文件播放器状态管理器 — 设置恢复与销毁持久化。
class PlaybackStateManager {
  PlaybackStateManager(this._controller);

  final PlaybackController _controller;
  bool _initialized = false;

  /// 恢复音量与静音设置。
  ///
  /// [settings] 可由组合根传入以复用已完成的设置 I/O；重复调用不会再次应用。
  Future<void> init({AppSettings? settings}) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final resolvedSettings = settings ?? await SettingsStore.load();
      _controller.engine.setVolume(resolvedSettings.volume);
      _controller.engine.setMute(resolvedSettings.isMuted);
    } on Exception catch (error) {
      _log.e('PlaybackStateManager.init load settings failed: $error');
    }
  }

  /// 异步保存音量与静音，不阻塞播放器销毁流程。
  void dispose() {
    // 设置写入与引擎资源释放互不依赖，因此显式采用 fire-and-forget。
    unawaited(
      SettingsStore.saveVolume(_controller.engine.volume.value).catchError(
        (Object error) => _log.e('SettingsStore.saveVolume failed: $error'),
      ),
    );
    unawaited(
      SettingsStore.saveIsMuted(_controller.engine.isMuted.value).catchError(
        (Object error) => _log.e('SettingsStore.saveIsMuted failed: $error'),
      ),
    );
  }
}
