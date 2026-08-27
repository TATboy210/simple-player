import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_dialog.dart';

void main() {
  // 固定中文 locale — 文案断言（标题/导航/分区名）不随宿主环境漂移。
  Widget buildSubject() => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => SettingsDialog.show(context),
            child: const Text('打开设置'),
          ),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle(); // 弹出动画 + 内容淡入完成
  }

  testWidgets('shows a two-pane shell with nav entries', (tester) async {
    await openDialog(tester);

    // 壳：标题 + 左侧导航（关于 = 唯一真实项；通用/视频/音频为灰显占位）。
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
  });

  testWidgets('about pane lists real open-source components and licenses', (
    tester,
  ) async {
    await openDialog(tester);

    // 开源技术区 — 顶部组件（真实在用的引擎封装与框架）必在首屏。
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    // LGPL 组件（mpv/libmpv 与 FFmpeg）共用同一许可证标识。
    expect(find.text('LGPL-2.1-or-later'), findsNWidgets(2));
  });

  testWidgets('about pane shows the special-thanks section at the bottom', (
    tester,
  ) async {
    await openDialog(tester);

    // 名单区位于长列表尾部 — ListView 惰性构建，先滚到它再断言。
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('特别鸣谢'),
      120,
      scrollable: list,
    );
    expect(find.text('特别鸣谢'), findsOneWidget);
    // 名单尚未录入 — 显示空态占位文案。
    expect(find.text('名单正在准备中，敬请期待'), findsOneWidget);
  });

  testWidgets('closes via the built-in close button', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle(); // 关闭动画走完

    // 回到承载页 — 入口按钮仍在，弹层消失以右区标题消失为准。
    expect(find.text('打开设置'), findsOneWidget);
    expect(find.text('关于'), findsNothing);
  });
}
