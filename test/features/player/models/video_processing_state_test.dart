/// VideoProcessingState 单元测试
///
/// 覆盖：默认值、copyWith、相等性、hashCode、VideoProcessingPatch
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/models/video_processing_state.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';

void main() {
  group('VideoProcessingState', () {
    group('defaults', () {
      test('all fields have zero/false/baseline values', () {
        const state = VideoProcessingState();
        expect(state.brightness, 0.0);
        expect(state.contrast, 0.0);
        expect(state.saturation, 0.0);
        expect(state.hue, 0.0);
        expect(state.deinterlaceEnabled, false);
        expect(state.rotation, 0);
        expect(state.aspectRatioMode, AspectRatioMode.keepOriginal);
      });

      test('defaults const is identical to default constructor', () {
        expect(VideoProcessingState.defaults, const VideoProcessingState());
      });
    });

    group('copyWith', () {
      test('returns new instance with updated brightness', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(brightness: 0.5);
        expect(updated.brightness, 0.5);
        expect(updated.contrast, 0.0);
        expect(updated, isNot(original));
      });

      test('returns new instance with updated contrast', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(contrast: -0.3);
        expect(updated.contrast, -0.3);
        expect(updated.brightness, 0.0);
      });

      test('returns new instance with updated deinterlaceEnabled', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(deinterlaceEnabled: true);
        expect(updated.deinterlaceEnabled, true);
      });

      test('returns new instance with updated rotation', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(rotation: 90);
        expect(updated.rotation, 90);
      });

      test('returns new instance with updated aspectRatioMode', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(
          aspectRatioMode: AspectRatioMode.ratio16_9,
        );
        expect(updated.aspectRatioMode, AspectRatioMode.ratio16_9);
      });

      test('copies multiple fields at once', () {
        const original = VideoProcessingState();
        final updated = original.copyWith(
          brightness: 0.5,
          contrast: -0.2,
          rotation: 180,
        );
        expect(updated.brightness, 0.5);
        expect(updated.contrast, -0.2);
        expect(updated.rotation, 180);
        expect(updated.saturation, 0.0);
      });

      test('null parameters preserve original values', () {
        const original = VideoProcessingState(
          brightness: 0.5,
          contrast: -0.3,
          rotation: 90,
        );
        final copied = original.copyWith();
        expect(copied, original);
      });
    });

    group('equality', () {
      test('identical states are equal', () {
        const a = VideoProcessingState(brightness: 0.5);
        const b = VideoProcessingState(brightness: 0.5);
        expect(a, b);
      });

      test('different brightness breaks equality', () {
        const a = VideoProcessingState(brightness: 0.5);
        const b = VideoProcessingState(brightness: 0.6);
        expect(a, isNot(b));
      });

      test('different deinterlaceEnabled breaks equality', () {
        const a = VideoProcessingState(deinterlaceEnabled: false);
        const b = VideoProcessingState(deinterlaceEnabled: true);
        expect(a, isNot(b));
      });

      test('different rotation breaks equality', () {
        const a = VideoProcessingState(rotation: 0);
        const b = VideoProcessingState(rotation: 90);
        expect(a, isNot(b));
      });

      test('different aspectRatioMode breaks equality', () {
        const a = VideoProcessingState(
          aspectRatioMode: AspectRatioMode.keepOriginal,
        );
        const b = VideoProcessingState(
          aspectRatioMode: AspectRatioMode.ratio16_9,
        );
        expect(a, isNot(b));
      });

      test('identical reference returns true', () {
        const a = VideoProcessingState(brightness: 0.5);
        expect(a == a, true);
      });
    });

    group('hashCode', () {
      test('equal states have same hashCode', () {
        const a = VideoProcessingState(brightness: 0.5, rotation: 90);
        const b = VideoProcessingState(brightness: 0.5, rotation: 90);
        expect(a.hashCode, b.hashCode);
      });

      test('different states have different hashCodes', () {
        const a = VideoProcessingState(brightness: 0.5);
        const b = VideoProcessingState(brightness: 0.6);
        expect(a.hashCode, isNot(b.hashCode));
      });
    });
  });

  group('VideoProcessingPatch', () {
    group('defaults', () {
      test('all fields default to false', () {
        const patch = VideoProcessingPatch();
        expect(patch.brightness, false);
        expect(patch.contrast, false);
        expect(patch.saturation, false);
        expect(patch.hue, false);
        expect(patch.deinterlaceEnabled, false);
        expect(patch.rotation, false);
        expect(patch.aspectRatioMode, false);
      });
    });

    group('hasAny', () {
      test('returns false when all fields are false', () {
        const patch = VideoProcessingPatch();
        expect(patch.hasAny, false);
      });

      test('returns true when brightness changed', () {
        const patch = VideoProcessingPatch(brightness: true);
        expect(patch.hasAny, true);
      });

      test('returns true when any field changed', () {
        const patch = VideoProcessingPatch(rotation: true);
        expect(patch.hasAny, true);
      });
    });

    group('isColorAdjustment', () {
      test('returns false when no color fields changed', () {
        const patch = VideoProcessingPatch(
          deinterlaceEnabled: true,
          rotation: true,
        );
        expect(patch.isColorAdjustment, false);
      });

      test('returns true when brightness changed', () {
        const patch = VideoProcessingPatch(brightness: true);
        expect(patch.isColorAdjustment, true);
      });

      test('returns true when contrast changed', () {
        const patch = VideoProcessingPatch(contrast: true);
        expect(patch.isColorAdjustment, true);
      });

      test('returns true when saturation changed', () {
        const patch = VideoProcessingPatch(saturation: true);
        expect(patch.isColorAdjustment, true);
      });

      test('returns true when hue changed', () {
        const patch = VideoProcessingPatch(hue: true);
        expect(patch.isColorAdjustment, true);
      });
    });
  });
}
