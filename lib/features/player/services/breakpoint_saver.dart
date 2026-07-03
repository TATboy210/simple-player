import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/playlist/playlist.dart';

/// 断点保存策略 — 引擎暂停时保存当前播放位置
class BreakpointSaver {
  BreakpointSaver({
    required this.engine,
    required this.playlist,
  });

  final EngineState engine;
  final Playlist playlist;

  void init() {
    engine.state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (engine.state.value != MediaState.paused) return;
    final idx = playlist.currentIndex;
    if (idx < 0) return;
    playlist.updatePosition(
      idx,
      engine.position.value,
      engine.duration.value,
    );
    PlaylistStore.save(playlist);
  }

  /// dispose 时也保存一次当前位置
  void dispose() {
    engine.state.removeListener(_onStateChanged);
    final idx = playlist.currentIndex;
    if (idx >= 0 && engine.position.value > 0) {
      playlist.updatePosition(
        idx,
        engine.position.value,
        engine.duration.value,
      );
      PlaylistStore.save(playlist);
    }
  }
}
