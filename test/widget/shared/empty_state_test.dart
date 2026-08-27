import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';

void main() {
  Widget buildSubject({VoidCallback? onOpenFile, bool dragHovering = false}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EmptyState(
            onOpenFile: onOpenFile,
            isDragHovering: dragHovering,
          ),
        ),
      );

  testWidgets('the open-file button is immediately tappable', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(buildSubject(onOpenFile: () => openCount++));

    // 空置态挂载即完整显示（无延迟/无入场动画）— 按钮立即可点。
    await tester.tap(find.byIcon(Icons.folder_open));
    expect(openCount, 1);
  });

  testWidgets('unmounting disposes safely', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(tester.takeException(), isNull);
  });
}
