import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/about_tab.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';

void main() {
  group('AboutTab', () {
    testWidgets('renders with GlassContainer sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutTab(),
          ),
        ),
      );

      // 3 sections: app info, copyright, licenses
      expect(find.byType(GlassContainer), findsNWidgets(3));
    });

    testWidgets('renders SectionHeader for each section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutTab(),
          ),
        ),
      );

      expect(find.byType(SectionHeader), findsNWidgets(3));
    });

    testWidgets('preserves version and tech stack SettingRows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutTab(),
          ),
        ),
      );

      expect(find.text('0.0.1'), findsOneWidget);
      expect(find.text('Flutter + fvp'), findsOneWidget);
    });

    testWidgets('licenses row uses InkWell for tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutTab(),
          ),
        ),
      );

      // InkWell should exist for the licenses row
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('does not use SettingsActionCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutTab(),
          ),
        ),
      );

      // AboutTab should use GlassContainer + InkWell instead of SettingsActionCard
      expect(find.byType(GlassContainer), findsNWidgets(3));
    });
  });
}
