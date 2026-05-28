import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/features/player/models/video_processing_state.dart';

void main() {
  group('VideoProcessingState', () {
    test('defaults has all zeros and false', () {
      const d = VideoProcessingState.defaults;
      expect(d.brightness, 0.0);
      expect(d.contrast, 0.0);
      expect(d.saturation, 0.0);
      expect(d.hue, 0.0);
      expect(d.deinterlaceEnabled, false);
      expect(d.rotation, 0);
      expect(d.aspectRatioMode, AspectRatioMode.keepOriginal);
    });

    test('copyWith replaces specified fields', () {
      const original = VideoProcessingState();
      final updated = original.copyWith(
        brightness: 0.5,
        rotation: 90,
        deinterlaceEnabled: true,
      );
      expect(updated.brightness, 0.5);
      expect(updated.rotation, 90);
      expect(updated.deinterlaceEnabled, true);
      expect(updated.contrast, 0.0); // unchanged
      expect(updated.saturation, 0.0); // unchanged
    });

    test('equality compares all fields', () {
      const a = VideoProcessingState(
        brightness: 0.1,
        contrast: 0.2,
        saturation: 0.3,
        hue: 0.4,
        deinterlaceEnabled: true,
        rotation: 180,
        aspectRatioMode: AspectRatioMode.ratio16_9,
      );
      const b = VideoProcessingState(
        brightness: 0.1,
        contrast: 0.2,
        saturation: 0.3,
        hue: 0.4,
        deinterlaceEnabled: true,
        rotation: 180,
        aspectRatioMode: AspectRatioMode.ratio16_9,
      );
      expect(a, b);
    });

    test('inequality on any field difference', () {
      const base = VideoProcessingState(brightness: 0.5);
      expect(base == const VideoProcessingState(brightness: 0.6), false);
      expect(base == const VideoProcessingState(contrast: 0.5), false);
      expect(
        base ==
            const VideoProcessingState(
              brightness: 0.5,
              deinterlaceEnabled: true,
            ),
        false,
      );
    });

    test('hashCode consistent for equal states', () {
      const a = VideoProcessingState(rotation: 270);
      const b = VideoProcessingState(rotation: 270);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('VideoProcessingPatch', () {
    test('default has all false', () {
      const patch = VideoProcessingPatch();
      expect(patch.brightness, false);
      expect(patch.contrast, false);
      expect(patch.saturation, false);
      expect(patch.hue, false);
      expect(patch.deinterlaceEnabled, false);
      expect(patch.rotation, false);
      expect(patch.aspectRatioMode, false);
    });

    test('hasAny is false when all fields are false', () {
      expect(const VideoProcessingPatch().hasAny, false);
    });

    test('hasAny is true when any field is true', () {
      expect(const VideoProcessingPatch(brightness: true).hasAny, true);
      expect(const VideoProcessingPatch(rotation: true).hasAny, true);
      expect(
        const VideoProcessingPatch(aspectRatioMode: true).hasAny,
        true,
      );
    });

    test('isColorAdjustment true for brightness/contrast/saturation/hue', () {
      expect(
        const VideoProcessingPatch(brightness: true).isColorAdjustment,
        true,
      );
      expect(
        const VideoProcessingPatch(contrast: true).isColorAdjustment,
        true,
      );
      expect(
        const VideoProcessingPatch(saturation: true).isColorAdjustment,
        true,
      );
      expect(
        const VideoProcessingPatch(hue: true).isColorAdjustment,
        true,
      );
    });

    test('isColorAdjustment false for non-color fields', () {
      expect(
        const VideoProcessingPatch(rotation: true).isColorAdjustment,
        false,
      );
      expect(
        const VideoProcessingPatch(deinterlaceEnabled: true)
            .isColorAdjustment,
        false,
      );
      expect(
        const VideoProcessingPatch(aspectRatioMode: true).isColorAdjustment,
        false,
      );
    });
  });
}
