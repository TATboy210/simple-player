// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters — 测试/脚本惯例 (空回调兜底/断言辅助/async testWidgets), 非生产缺陷.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/right_button_group.dart';

void main() {
  Widget buildSubject(PlayerActions actions) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: RightButtonGroup(actions: actions)),
    ),
  );

  testWidgets('places the settings button between subtitle and fullscreen', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(
      buildSubject(
        PlayerActions(
          onOpenSubtitle: () {},
          onOpenSettings: () => openCount++,
          onToggleFullscreen: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // 横向次序契约：字幕 < 设置 < 全屏。
    final subtitleX = tester.getCenter(find.byIcon(Icons.subtitles)).dx;
    final gearX = tester.getCenter(find.byIcon(Icons.settings_outlined)).dx;
    final fullscreenX = tester.getCenter(find.byIcon(Icons.fullscreen)).dx;
    expect(
      subtitleX < gearX && gearX < fullscreenX,
      isTrue,
      reason: '设置按钮必须位于字幕与全屏切换之间',
    );

    // 点击触发注入的回调。
    await tester.tap(find.byIcon(Icons.settings_outlined));
    expect(openCount, 1);
  });

  testWidgets('omits the settings button when onOpenSettings is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(const PlayerActions(onOpenSubtitle: null)),
    );

    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
}
