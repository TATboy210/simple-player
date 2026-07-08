import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/video_tab.dart';
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

  group('VideoTab', () {
    testWidgets('shows unavailable message when videoProcessing is null',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(const VideoTab()));

      // Should show unavailable message
      expect(find.text('Video processing unavailable'), findsOneWidget);
    });

    testWidgets('does not render GlassContainer when null', (tester) async {
      await tester.pumpWidget(buildTestWidget(const VideoTab()));

      // No GlassContainer when videoProcessing is null
      expect(find.byType(GlassContainer), findsNothing);
    });
  });
}
