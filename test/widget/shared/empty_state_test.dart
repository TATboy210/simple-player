import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';

void main() {
  Widget buildSubject({VoidCallback? onOpenFile}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: EmptyState(onOpenFile: onOpenFile)),
  );

  testWidgets('enables the open-file button after the empty-state delay', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(buildSubject(onOpenFile: () => openCount++));

    // 按钮保留布局，但在上一媒体表面完成退场前不得接收交互。
    await tester.tap(find.byIcon(Icons.folder_open), warnIfMissed: false);
    expect(openCount, 0);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.folder_open));
    expect(openCount, 1);
  });

  testWidgets(
    'cancels the delayed enablement when the empty state is removed',
    (tester) async {
      var openCount = 0;
      await tester.pumpWidget(buildSubject(onOpenFile: () => openCount++));

      // Removing the empty state must dispose its timer before a new media view
      // can be affected by the old delayed callback.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(seconds: 2));

      expect(openCount, 0);
    },
  );
}
