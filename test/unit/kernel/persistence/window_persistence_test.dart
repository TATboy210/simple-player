import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/persistence/window_persistence.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_constants.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<WindowPersistence> createStore() async =>
      WindowPersistence(preferences: await SharedPreferences.getInstance());

  group('WindowPersistence', () {
    test(
      'returns the stable 1280x752 default when no state was saved',
      () async {
        final state = await (await createStore()).load();

        expect(state.size, defaultWindowSize);
        expect(state.position, isNull);
        expect(state.alwaysOnTop, isFalse);
        expect(state.isMaximized, isFalse);
      },
    );

    test('round-trips settled geometry and always-on-top preference', () async {
      final store = await createStore();
      const expected = PersistedWindowState(
        size: Size(1440, 900),
        position: Offset(120, 80),
        alwaysOnTop: true,
        isMaximized: true,
      );

      await store.save(expected);
      final actual = await store.load();

      expect(actual.size, expected.size);
      expect(actual.position, expected.position);
      expect(actual.alwaysOnTop, isTrue);
      expect(actual.isMaximized, isTrue);
    });

    test(
      'falls back for invalid persisted dimensions and coordinates',
      () async {
        SharedPreferences.setMockInitialValues({
          'windowWidth': double.nan,
          'windowHeight': 100.0,
          'windowX': double.infinity,
          'windowY': -double.infinity,
        });
        final state = await (await createStore()).load();

        expect(state.size, defaultWindowSize);
        expect(state.position, isNull);
        expect(state.isMaximized, isFalse);
      },
    );
  });
}
