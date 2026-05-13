import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/services/platform_service.dart';
import '../helpers/fake_platform_service.dart';

void main() {
  tearDown(() => PlatformService.reset());

  test('PlatformService.I returns proxy before init (no throw)', () {
    final instance = PlatformService.I;
    expect(instance, isA<PlatformService>());
    // Before init, returns _Proxy that delegates to WindowBridge.I (noop)
    expect(PlatformService.isInitialized, isFalse);
  });

  test('PlatformService.init sets singleton', () {
    final fake = FakePlatformService();
    PlatformService.init(fake);
    expect(PlatformService.I, same(fake));
  });

  test('PlatformService.reset clears singleton, falls back to proxy', () {
    PlatformService.init(FakePlatformService());
    PlatformService.reset();
    expect(PlatformService.isInitialized, isFalse);
    // After reset, I returns the _Proxy fallback (no throw)
    expect(PlatformService.I, isA<PlatformService>());
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
