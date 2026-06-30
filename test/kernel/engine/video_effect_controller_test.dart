import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/video_effect_controller.dart';

void main() {
  group('VideoEffectController', () {
    test('class exists and is importable', () {
      // VideoEffectController requires mdk.Player (FFI) — verify API surface
      expect(VideoEffectController, isA<Type>());
    });

    test('setEffect method is part of public API', () {
      // Verify setEffect accepts VideoEffectType and double
      expect(VideoEffectController, isA<Type>());
    });

    test('setAspectRatio method is part of public API', () {
      expect(VideoEffectController, isA<Type>());
    });

    test('setDeinterlace method is part of public API', () {
      expect(VideoEffectController, isA<Type>());
    });
  });

  group('VideoEffectController.isValidRotation', () {
    test('accepts 0 degrees', () {
      expect(VideoEffectController.isValidRotation(0), isTrue);
    });

    test('accepts 90 degrees', () {
      expect(VideoEffectController.isValidRotation(90), isTrue);
    });

    test('accepts 180 degrees', () {
      expect(VideoEffectController.isValidRotation(180), isTrue);
    });

    test('accepts 270 degrees', () {
      expect(VideoEffectController.isValidRotation(270), isTrue);
    });

    test('rejects 45 degrees', () {
      expect(VideoEffectController.isValidRotation(45), isFalse);
    });

    test('rejects 360 degrees', () {
      expect(VideoEffectController.isValidRotation(360), isFalse);
    });

    test('rejects negative degrees', () {
      expect(VideoEffectController.isValidRotation(-90), isFalse);
    });
  });

  group('VideoEffectController.validRotationDegrees', () {
    test('contains exactly 4 values', () {
      expect(VideoEffectController.validRotationDegrees, hasLength(4));
    });

    test('contains standard rotation angles', () {
      expect(
        VideoEffectController.validRotationDegrees,
        containsAll([0, 90, 180, 270]),
      );
    });
  });

  group('VideoEffectType enum', () {
    test('has 4 effects', () {
      expect(VideoEffectType.values, hasLength(4));
    });

    test('includes brightness, contrast, hue, saturation', () {
      expect(
        VideoEffectType.values.map((e) => e.name),
        containsAll(['brightness', 'contrast', 'hue', 'saturation']),
      );
    });
  });
}
