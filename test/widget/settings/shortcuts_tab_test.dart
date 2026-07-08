import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/shortcuts_tab.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('ShortcutsTab', () {
    testWidgets('renders with GlassContainer', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ShortcutsTab()));

      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('renders SectionHeader', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ShortcutsTab()));

      expect(find.byType(SectionHeader), findsOneWidget);
    });

    testWidgets('renders shortcut rows', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ShortcutsTab()));

      // Should have multiple shortcut setting rows
      expect(find.text('Space'), findsOneWidget);
    });

    testWidgets('preserves keyboard listener structure', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ShortcutsTab()));

      // KeyboardListener should wrap the content
      expect(find.byType(KeyboardListener), findsOneWidget);
    });
  });
}
