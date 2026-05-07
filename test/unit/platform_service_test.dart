import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  tearDown(() => PlatformService.reset());

  test('PlatformService.I throws before init', () {
    expect(() => PlatformService.I, throwsStateError);
  });

  test('PlatformService.init sets singleton', () {
    final fake = FakePlatformService();
    PlatformService.init(fake);
    expect(PlatformService.I, same(fake));
  });

  test('PlatformService.reset clears singleton', () {
    PlatformService.init(FakePlatformService());
    PlatformService.reset();
    expect(() => PlatformService.I, throwsStateError);
  });

  test('mode defaults to windowed', () {
    final fake = FakePlatformService();
    expect(fake.mode.value, WindowMode.windowed);
  });

  test('isAlwaysOnTop defaults to false', () {
    final fake = FakePlatformService();
    expect(fake.isAlwaysOnTop.value, false);
  });

  test('isMaximized defaults to false', () {
    final fake = FakePlatformService();
    expect(fake.isMaximized.value, false);
  });

  test('isResizing defaults to false', () {
    final fake = FakePlatformService();
    expect(fake.isResizing.value, false);
  });

  test('FakePlatformService implements all window methods', () async {
    final fake = FakePlatformService();
    await fake.minimize();
    await fake.toggleMaximize();
    await fake.close();
    await fake.startDragging();
    await fake.toggleFullscreen();
    await fake.exitFullscreen();
    await fake.toggleAlwaysOnTop();
    expect(fake.minimizeCalls, 1);
    expect(fake.toggleMaximizeCalls, 1);
    expect(fake.closeCalls, 1);
    expect(fake.startDraggingCalls, 1);
    expect(fake.toggleFullscreenCalls, 1);
    expect(fake.exitFullscreenCalls, 1);
    expect(fake.toggleAlwaysOnTopCalls, 1);
  });
}
