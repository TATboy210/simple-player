import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';

void main() {
  group('AspectRatioMode', () {
    test('keepOriginal maps to mdk keepAspectRatio (~FLT_EPSILON)', () {
      expect(AspectRatioMode.keepOriginal.mdkValue, 1.1920928955078125e-7);
    });

    test('stretch maps to mdk ignoreAspectRatio (0.0)', () {
      expect(AspectRatioMode.stretch.mdkValue, 0.0);
    });

    test('cropFill maps to mdk keepAspectRatioCrop (~-FLT_EPSILON)', () {
      expect(AspectRatioMode.cropFill.mdkValue, -1.1920928955078125e-7);
    });

    test('ratio4_3 maps to 4/3', () {
      expect(AspectRatioMode.ratio4_3.mdkValue, closeTo(4.0 / 3.0, 1e-10));
    });

    test('ratio16_9 maps to 16/9', () {
      expect(AspectRatioMode.ratio16_9.mdkValue, closeTo(16.0 / 9.0, 1e-10));
    });

    test('ratio21_9 maps to 21/9', () {
      expect(AspectRatioMode.ratio21_9.mdkValue, closeTo(21.0 / 9.0, 1e-10));
    });

    test('all modes have non-empty labels', () {
      for (final mode in AspectRatioMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });

    test('has 6 values', () {
      expect(AspectRatioMode.values.length, 6);
    });
  });
}
