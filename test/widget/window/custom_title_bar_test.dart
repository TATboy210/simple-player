import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/window/window_service.dart';
import 'package:simple_player_flutter/ui/player/custom_title_bar.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';

void main() {

  Widget buildSubject({ValueNotifier<String>? fileName}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomTitleBar(fileName: fileName ?? ValueNotifier('')),
      ),
    );
  }

  group('文件名显示', () {
    testWidgets('fileName 为空时显示 "Simple Player"', (tester) async {
      await tester.pumpWidget(buildSubject(fileName: ValueNotifier('')));
      await tester.pump();
      expect(find.text('Simple Player'), findsOneWidget);
    });

    testWidgets('fileName 有值时显示 "{name} — Simple Player"', (tester) async {
      final notifier = ValueNotifier('video.mp4');
      await tester.pumpWidget(buildSubject(fileName: notifier));
      await tester.pump();
      expect(find.text('video.mp4 — Simple Player'), findsOneWidget);
    });
  });

  group('Pin 按钮状态反射 (WC-01, WC-05)', () {
    testWidgets('pin 按钮存在且显示 push_pin 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('alwaysOnTop 为 true 时 pin 图标为 accent 色', (tester) async {
      await tester.pumpWidget(buildSubject());
      WindowService.instance.state.alwaysOnTop.value = true;
      await tester.pump();
      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, const Color(0xFF2C58F4)); // Tokens.accent
    });

    testWidgets('alwaysOnTop 为 false 时 pin 图标为 textSecondary 色', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      WindowService.instance.state.alwaysOnTop.value = false;
      await tester.pump();
      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, const Color(0xFF9999AA)); // Tokens.textSecondary
    });
  });

  group('Maximize 按钮状态反射 (WC-03, WC-05)', () {
    testWidgets('未最大化时显示 crop_square 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
    });

    testWidgets('最大化后显示 filter_none 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      WindowService.instance.state.maximized.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
    });
  });

  group('窗口控制按钮存在 (WC-01..WC-04)', () {
    testWidgets('四个窗口控制按钮均存在', (tester) async {
      // Reset state leaked from prior tests
      WindowService.instance.state.alwaysOnTop.value = false;
      WindowService.instance.state.maximized.value = false;
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.minimize), findsOneWidget);
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
      // Close button: verify via Tooltip (Icons.close font not loaded in test env)
      final l10n = AppLocalizations.of(
        tester.element(find.byIcon(Icons.push_pin)),
      );
      expect(find.byTooltip(l10n.close), findsOneWidget);
    });
  });

}
