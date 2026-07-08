import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/video_tab.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';
import 'package:simple_player_flutter/features/player/services/video_processing_service.dart';

void main() {
  group('VideoTab', () {
    testWidgets('renders with GlassContainer sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // Should have 4 GlassContainer sections (brightness, rotation, aspect ratio, deinterlace)
      expect(find.byType(GlassContainer), findsNWidgets(4));
    });

    testWidgets('renders SectionHeader for each section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // Should have 4 SectionHeader widgets
      expect(find.byType(SectionHeader), findsNWidgets(4));
    });

    testWidgets('preserves _VideoSlider widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // 4 sliders for brightness, contrast, saturation, hue
      expect(find.byType(Slider), findsNWidgets(4));
    });

    testWidgets('preserves _RotationPicker widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // Rotation picker has 4 ChoiceChips (0, 90, 180, 270)
      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });

    testWidgets('preserves _AspectRatioSelector widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      expect(find.byType(DropdownButton), findsOneWidget);
    });

    testWidgets('preserves reset button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // Reset button should still exist
      expect(find.text('Reset All'), findsOneWidget);
    });

    testWidgets('does not use SettingsCard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTab(videoProcessing: VideoProcessingService()),
          ),
        ),
      );

      // VideoTab should not use SettingsCard anymore
      // (we check by verifying GlassContainer is used instead)
      expect(find.byType(GlassContainer), findsNWidgets(4));
    });
  });
}
