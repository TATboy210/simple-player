import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/shortcuts_tab.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';

void main() {
  group('ShortcutsTab', () {
    testWidgets('renders with GlassContainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsTab(),
          ),
        ),
      );

      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('renders SectionHeader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsTab(),
          ),
        ),
      );

      expect(find.byType(SectionHeader), findsOneWidget);
    });

    testWidgets('renders shortcut rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsTab(),
          ),
        ),
      );

      // Should have multiple shortcut setting rows
      // At minimum: playPause, seekBackward, seekForward, volumeUp, volumeDown, fullscreen, etc.
      expect(find.text('Space'), findsOneWidget);
    });

    testWidgets('preserves reset button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsTab(),
          ),
        ),
      );

      // Reset button should still exist
      expect(find.text('Reset Shortcuts'), findsOneWidget);
    });

    testWidgets('preserves keyboard listener structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsTab(),
          ),
        ),
      );

      // KeyboardListener should wrap the content
      expect(find.byType(KeyboardListener), findsOneWidget);
    });
  });
}
