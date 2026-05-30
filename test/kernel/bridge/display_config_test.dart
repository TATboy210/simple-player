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
  });
}
