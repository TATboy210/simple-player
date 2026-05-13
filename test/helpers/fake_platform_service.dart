import 'package:flutter/foundation.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/services/platform_service.dart';

/// Fake implementation for testing the interface contract
class FakePlatformService implements PlatformService {
  @override
  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  @override
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  @override
  final isMaximized = ValueNotifier<bool>(false);
  @override
  final isResizing = ValueNotifier<bool>(false);

  int minimizeCalls = 0;
  int toggleMaximizeCalls = 0;
  int closeCalls = 0;
  int startDraggingCalls = 0;
  int toggleFullscreenCalls = 0;
  int exitFullscreenCalls = 0;
  int toggleAlwaysOnTopCalls = 0;

  @override
  Future<void> minimize() async => minimizeCalls++;
  @override
  Future<void> toggleMaximize() async => toggleMaximizeCalls++;
  @override
  Future<void> close() async => closeCalls++;
  @override
  Future<void> startDragging() async => startDraggingCalls++;
  @override
  Future<void> toggleFullscreen() async => toggleFullscreenCalls++;
  @override
  Future<void> exitFullscreen() async => exitFullscreenCalls++;
  @override
  Future<void> toggleAlwaysOnTop() async => toggleAlwaysOnTopCalls++;
  @override
  Future<void> initService() async {}
  @override
  Future<void> dispose() async {}
}
