import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/window/geometry_store.dart';

void main() {
  group('WindowGeometry', () {
    test('position returns Offset from x,y', () {
      const geo = WindowGeometry(
        width: 800, height: 600, x: 100, y: 200,
      );
      expect(geo.position, const Offset(100, 200));
    });

    test('size returns Size from width,height', () {
      const geo = WindowGeometry(
        width: 800, height: 600, x: 0, y: 0,
      );
      expect(geo.size, const Size(800, 600));
    });

    test('isMaximized defaults to false', () {
      const geo = WindowGeometry(
        width: 800, height: 600, x: 0, y: 0,
      );
      expect(geo.isMaximized, false);
    });

    test('isFullscreen defaults to false', () {
      const geo = WindowGeometry(
        width: 800, height: 600, x: 0, y: 0,
      );
      expect(geo.isFullscreen, false);
    });
  });

  group('WindowGeometryStore load', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults are 1280x720 at position 10,10', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);
      final geo = store.load();

      expect(geo.width, 1280.0);
      expect(geo.height, 720.0);
      expect(geo.x, 10.0);
      expect(geo.y, 10.0);
      expect(geo.isMaximized, false);
      expect(geo.isFullscreen, false);
    });

    test('reads saved values', () async {
      SharedPreferences.setMockInitialValues({
        'windowWidth': 1920.0,
        'windowHeight': 1080.0,
        'windowX': 50.0,
        'windowY': 60.0,
        'windowIsMaximized': true,
        'windowIsFullscreen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);
      final geo = store.load();

      expect(geo.width, 1920.0);
      expect(geo.height, 1080.0);
      expect(geo.x, 50.0);
      expect(geo.y, 60.0);
      expect(geo.isMaximized, true);
      expect(geo.isFullscreen, true);
    });
  });

  group('WindowGeometryStore saveFullscreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists fullscreen true', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      await store.saveFullscreen(true);
      expect(prefs.getBool('windowIsFullscreen'), true);
    });

    test('persists fullscreen false', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      await store.saveFullscreen(true);
      await store.saveFullscreen(false);
      expect(prefs.getBool('windowIsFullscreen'), false);
    });
  });

  group('WindowGeometryStore saveImmediate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('writes all values immediately', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      await store.saveImmediate(
        size: const Size(1024, 768),
        position: const Offset(20, 30),
        isMaximized: true,
      );

      expect(prefs.getDouble('windowWidth'), 1024.0);
      expect(prefs.getDouble('windowHeight'), 768.0);
      expect(prefs.getDouble('windowX'), 20.0);
      expect(prefs.getDouble('windowY'), 30.0);
      expect(prefs.getBool('windowIsMaximized'), true);
    });

    test('cancels pending debounced write', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      // Start a debounced write
      store.saveDebounced(
        size: const Size(800, 600),
        position: const Offset(0, 0),
        isMaximized: false,
      );

      // Immediate write should cancel debounce
      await store.saveImmediate(
        size: const Size(1024, 768),
        position: const Offset(10, 10),
        isMaximized: true,
      );

      expect(prefs.getDouble('windowWidth'), 1024.0);
    });
  });

  group('WindowGeometryStore saveDebounced', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('coalesces multiple calls into one write', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      store.saveDebounced(
        size: const Size(800, 600),
        position: const Offset(0, 0),
        isMaximized: false,
      );
      store.saveDebounced(
        size: const Size(1024, 768),
        position: const Offset(10, 10),
        isMaximized: true,
      );

      // Before debounce fires, nothing written
      expect(prefs.getDouble('windowWidth'), isNull);

      // Wait for debounce (500ms + buffer)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Only last call's values written
      expect(prefs.getDouble('windowWidth'), 1024.0);
      expect(prefs.getDouble('windowHeight'), 768.0);
      expect(prefs.getBool('windowIsMaximized'), true);
    });
  });

  group('WindowGeometryStore flush', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('cancels pending debounce and completes', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      store.saveDebounced(
        size: const Size(800, 600),
        position: const Offset(0, 0),
        isMaximized: false,
      );

      // flush cancels debounce — should not hang
      await store.flush();

      // Debounce was cancelled, so value NOT written
      expect(prefs.getDouble('windowWidth'), isNull);
    });

    test('completes immediately when nothing pending', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      // Should not hang
      await store.flush();
    });
  });

  group('WindowGeometryStore round-trip', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save then load preserves values', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowGeometryStore(prefs);

      await store.saveImmediate(
        size: const Size(1920, 1080),
        position: const Offset(100, 200),
        isMaximized: true,
      );

      final geo = store.load();
      expect(geo.width, 1920.0);
      expect(geo.height, 1080.0);
      expect(geo.x, 100.0);
      expect(geo.y, 200.0);
      expect(geo.isMaximized, true);
    });
  });

  group('WindowGeometryStore.clampToVisibleBounds', () {
    test('returns original geometry when on-screen', () {
      const geo = WindowGeometry(
        width: 800, height: 600, x: 100, y: 100,
      );
      final clamped = WindowGeometryStore.clampToVisibleBounds(geo);
      expect(clamped.x, 100.0);
      expect(clamped.y, 100.0);
      expect(clamped.width, 800.0);
      expect(clamped.height, 600.0);
    });

    test('preserves size when repositioning off-screen window', () {
      // Window far off-screen (negative position)
      const geo = WindowGeometry(
        width: 800, height: 600, x: -2000, y: -2000,
      );
      final clamped = WindowGeometryStore.clampToVisibleBounds(geo);
      expect(clamped.width, 800.0);
      expect(clamped.height, 600.0);
    });
  });
}
