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

  testWidgets('content reveals after the delay and the button opens files', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(buildSubject(onOpenFile: () => openCount++));

    // 入场编排：内容停 1 秒（emptyContentRevealDelayMs）后随 _contentReveal
    // 淡入。极光为无限 ticker，禁用 pumpAndSettle，用固定时长推进：
    // 1000ms 延迟触发 + 500ms 覆盖 400ms 淡入。
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.folder_open));
    expect(openCount, 1);
  });

  testWidgets('unmounting during the reveal delay disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    // 在 1 秒延迟窗口内直接移除组件 — 定时器取消必须安全。
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
  });
}
