import '../state/playback_state.dart';

// ============================================================
// 事件 — Feature → UI 的状态通知
// ============================================================

/// 事件基类 — 所有模块通过 EventBus 通信
sealed class PlayerEvent {
  const PlayerEvent();
}

final class StateChanged extends PlayerEvent {
  final PlaybackState state;
  const StateChanged(this.state);
}

final class PositionChanged extends PlayerEvent {
  final int positionMs;
  final int durationMs;
  const PositionChanged(this.positionMs, this.durationMs);
}

final class MediaOpened extends PlayerEvent {
  final String path;
  const MediaOpened(this.path);
}

final class MediaInfoUpdated extends PlayerEvent {
  final Map<String, String> info;
  const MediaInfoUpdated(this.info);
}

final class ErrorOccurred extends PlayerEvent {
  final String message;
  final String? code;
  const ErrorOccurred(this.message, [this.code]);
}

final class VolumeChanged extends PlayerEvent {
  final double volume;
  const VolumeChanged(this.volume);
}

final class MuteChanged extends PlayerEvent {
  final bool muted;
  const MuteChanged(this.muted);
}

final class TrackChanged extends PlayerEvent {
  final String trackType; // 'audio', 'video', 'sub'
  final int? trackId;
  const TrackChanged(this.trackType, [this.trackId]);
}

final class TracksUpdated extends PlayerEvent {
  final List<TrackInfo> tracks;
  const TracksUpdated(this.tracks);
}

/// 渲染纹理创建完成 — C++ 插件分配 GPU 纹理后触发
final class TextureCreated extends PlayerEvent {
  final int textureId;
  final int width;
  final int height;
  const TextureCreated(this.textureId, this.width, this.height);
}

/// 轨道信息 — 不可变
class TrackInfo {
  final int id;
  final String type; // 'audio', 'video', 'sub'
  final String? title;
  final String? lang;
  final bool selected;

  const TrackInfo({
    required this.id,
    required this.type,
    this.title,
    this.lang,
    this.selected = false,
  });
}

// ============================================================
// 命令 — UI → Feature 的操作指令
// ============================================================

/// 播放器命令 — UI → Feature 的唯一通道
sealed class PlayerCommand extends PlayerEvent {
  const PlayerCommand();
}

final class OpenCommand extends PlayerCommand {
  final String path;
  const OpenCommand(this.path);
}

final class PlayCommand extends PlayerCommand {
  const PlayCommand();
}

final class PauseCommand extends PlayerCommand {
  const PauseCommand();
}

final class TogglePlayPauseCommand extends PlayerCommand {
  const TogglePlayPauseCommand();
}

final class StopCommand extends PlayerCommand {
  const StopCommand();
}

final class PrevCommand extends PlayerCommand {
  const PrevCommand();
}

final class NextCommand extends PlayerCommand {
  const NextCommand();
}

final class VolumeUpCommand extends PlayerCommand {
  const VolumeUpCommand();
}

final class VolumeDownCommand extends PlayerCommand {
  const VolumeDownCommand();
}

final class ToggleMuteCommand extends PlayerCommand {
  const ToggleMuteCommand();
}

final class ToggleFullscreenCommand extends PlayerCommand {
  const ToggleFullscreenCommand();
}

final class SeekCommand extends PlayerCommand {
  final int positionMs;
  const SeekCommand(this.positionMs);
}

final class SetVolumeCommand extends PlayerCommand {
  final double volume;
  const SetVolumeCommand(this.volume);
}

final class SkipForwardCommand extends PlayerCommand {
  final int seconds;
  const SkipForwardCommand({this.seconds = 10});
}

final class SkipBackwardCommand extends PlayerCommand {
  final int seconds;
  const SkipBackwardCommand({this.seconds = 10});
}
