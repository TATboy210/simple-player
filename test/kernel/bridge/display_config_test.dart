import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_config.dart';

void main() {
  group('DisplayConfig.syncModeForHz', () {
    tearDown(() => DisplayConfig.reset());

    test('60Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(60), '1');
    });

    test('120Hz returns async mode (0)', () {
      expect(DisplayConfig.syncModeForHz(120), '0');
    });

    test('144Hz returns async mode (0)', () {
      expect(DisplayConfig.syncModeForHz(144), '0');
    });

    test('75Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(75), '1');
    });

    test('240Hz returns async mode (0)', () {
      expect(DisplayConfig.syncModeForHz(240), '0');
    });

    test('30Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(30), '1');
    });

    test('59Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(59), '1');
    });

    test('0Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(0), '1');
    });

    test('negative Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(-1), '1');
    });

    test('very large Hz returns async mode (0)', () {
      expect(DisplayConfig.syncModeForHz(999), '0');
    });
  });

  group('DisplayConfig cold startup', () {
    tearDown(() => DisplayConfig.reset());

    test('getRefreshRate returns 60 before init()', () {
      // Before init(), should return safe default
      expect(DisplayConfig.getRefreshRate(), 60);
    });

    test('d3d11SyncMode returns sync (1) before init()', () {
      // Before init(), 60Hz → sync mode
      expect(DisplayConfig.d3d11SyncMode(), '1');
    });

    test('init() is idempotent', () {
      DisplayConfig.init();
      final hz1 = DisplayConfig.getRefreshRate();
      DisplayConfig.init();
      final hz2 = DisplayConfig.getRefreshRate();
      expect(hz1, hz2);
    });

    test('reset() clears cached state', () {
      DisplayConfig.init();
      DisplayConfig.reset();
      // After reset, should return default 60 again
      expect(DisplayConfig.getRefreshRate(), 60);
    });
  });
}
