import 'package:flutter/material.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';

import 'fake_engine.dart';
import 'fake_window_service.dart';

/// Wrap [child] in a minimal MaterialApp for widget tests.
Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Create a PlaybackController wired to [engine] for single-file playback.
PlaybackController createTestController(FakeEngine engine) {
  return PlaybackController(engine: engine);
}

/// Create a FakeWindowService with sensible defaults.
FakeWindowService createFakeWindowService() => FakeWindowService();
