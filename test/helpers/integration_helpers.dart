import 'package:flutter/material.dart';
import 'package:simple_player_flutter/features/player/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';

import 'fake_engine.dart';
import 'fake_window_service.dart';

/// Wrap [child] in a minimal MaterialApp for widget tests.
Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Create a PlaybackController wired to [engine] with a no-op rebuild.
PlaybackController createTestController(FakeEngine engine) {
  final playlist = Playlist();
  return PlaybackController(
    engine: engine,
    playlist: playlist,
    onNeedRebuild: () {},
  );
}

/// Create a FakeWindowService with sensible defaults.
FakeWindowService createFakeWindowService() => FakeWindowService();
