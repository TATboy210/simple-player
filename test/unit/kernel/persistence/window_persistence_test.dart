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

    test(
      'reads legacy per-field keys when the snapshot blob is absent',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'windowWidth': 1440.0,
          'windowHeight': 900.0,
          'windowX': 120.0,
          'windowY': 80.0,
          'isAlwaysOnTop': true,
          'isMaximized': false,
        });
        final state = await (await createStore()).load();

        expect(state.size, const Size(1440, 900));
        expect(state.position, const Offset(120, 80));
        expect(state.alwaysOnTop, isTrue);
        expect(state.isMaximized, isFalse);
      },
    );

    test(
      'migrates legacy keys into the blob and cleans them up on save',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'windowWidth': 1440.0,
          'windowHeight': 900.0,
          'windowX': 120.0,
          'windowY': 80.0,
          'isAlwaysOnTop': true,
          'isMaximized': false,
        });
        final store = await createStore();
        final preferences = await SharedPreferences.getInstance();

        await store.save(
          const PersistedWindowState(
            size: Size(1440, 900),
            position: Offset(120, 80),
            alwaysOnTop: true,
            isMaximized: false,
          ),
        );

        // blob 落盘, 旧 key 一次性清除 — containsKey 短路保证后续 save
        // 零额外写盘。
        expect(preferences.getString('windowSnapshot'), isNotNull);
        for (final key in const [
          'windowWidth',
          'windowHeight',
          'windowX',
          'windowY',
          'isAlwaysOnTop',
          'isMaximized',
        ]) {
          expect(preferences.containsKey(key), isFalse, reason: key);
        }
      },
    );

    test(
      'falls back to legacy keys when the snapshot blob is corrupt',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'windowSnapshot': '{not json',
          'windowWidth': 1440.0,
          'windowHeight': 900.0,
        });
        final state = await (await createStore()).load();

        expect(state.size, const Size(1440, 900));
        expect(state.position, isNull);
      },
    );

    test('keeps null position through the snapshot blob round-trip', () async {
      final store = await createStore();

      await store.save(
        const PersistedWindowState(
          size: Size(1024, 600),
          position: null,
          alwaysOnTop: false,
          isMaximized: true,
        ),
      );
      final state = await store.load();

      expect(state.size, const Size(1024, 600));
      expect(state.position, isNull);
      expect(state.isMaximized, isTrue);
    });
  });
}
