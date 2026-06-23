import '../../infra/mpv/mpv_adapter.dart';
import '../../infra/event_bus/event_bus.dart';
import '../../core/events/player_events.dart';

/// 播放器功能模块 — 订阅命令，调用 MpvAdapter
///
/// 不直接暴露给 UI。UI 通过 EventBus.fire(Command) 发送命令。
/// 状态通过 EventBus.on<Event>() 回传。
class PlayerFeature {
  final MpvAdapter _mpv;
  final EventBus _bus;

  PlayerFeature(this._mpv, this._bus);

  /// 初始化 — 订阅命令事件
  void init() {
    _bus.on<PlayerCommand>().listen(_handleCommand);
  }

  Future<void> _handleCommand(PlayerCommand cmd) async {
    try {
      switch (cmd) {
        case OpenCommand(:final path):
          await _mpv.load(path);
        case PlayCommand():
          await _mpv.play();
        case PauseCommand():
          await _mpv.pause();
        case TogglePlayPauseCommand():
          await _mpv.togglePlayPause();
        case StopCommand():
          await _mpv.stop();
        case SeekCommand(:final positionMs):
          await _mpv.seekTo(positionMs);
        case SetVolumeCommand(:final volume):
          _mpv.setVolume(volume);
        case ToggleMuteCommand():
          _mpv.setMute(!_mpv.muted);
        case SkipForwardCommand(:final seconds):
          await _mpv.seekTo(_mpv.positionMs + seconds * 1000);
        case SkipBackwardCommand(:final seconds):
          await _mpv.seekTo(_mpv.positionMs - seconds * 1000);
        case PrevCommand():
          // TODO: 接入播放列表逻辑
          break;
        case NextCommand():
          // TODO: 接入播放列表逻辑
          break;
        case VolumeUpCommand():
          final newVol = (_mpv.volume + 5).clamp(0.0, 100.0);
          _mpv.setVolume(newVol);
          _bus.fire(VolumeChanged(newVol));
        case VolumeDownCommand():
          final newVol = (_mpv.volume - 5).clamp(0.0, 100.0);
          _mpv.setVolume(newVol);
          _bus.fire(VolumeChanged(newVol));
        case ToggleFullscreenCommand():
          // TODO: 接入 WindowService 全屏切换
          break;
      }
    } catch (e) {
      _bus.fire(ErrorOccurred('Command failed: $cmd — $e'));
    }
  }

  void dispose() {}
}
