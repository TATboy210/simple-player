import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_dialog.dart';

void main() {
  // 固定中文 locale — 文案断言（标题/占位/关闭钮）不随宿主环境漂移。
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

  testWidgets('shows the title, placeholder icon, and placeholder text', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.text('设置'), findsOneWidget); // AppDialog 标题
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('更多设置即将到来'), findsOneWidget);
  });

  testWidgets('closes via the built-in close button', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle(); // 关闭动画走完

    expect(find.text('更多设置即将到来'), findsNothing);
    // 回到承载页 — 入口按钮仍在。
    expect(find.text('打开设置'), findsOneWidget);
  });
}
