import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/playlist/playlist.dart';
import 'subtitle_service.dart';

/// 播放子模块的共享依赖契约
///
/// 子模块（PlaybackNavigator / FileOperations / AutoAdvancePolicy / BreakpointSaver）
/// 通过此接口访问共享资源，而非直接依赖 PlaybackController。
/// 这使得每个子模块可以独立构造和测试。
abstract interface class PlaybackContract {
  EngineState get engine;
  Playlist get playlist;
  SubtitleService? get subtitleService;
  void Function(Object error)? get onError;
  void Function() get onNeedRebuild;
  void Function(String fileName)? get onTrackChanged;
  void savePlaylist();
}
