// ignore_for_file: no-empty-block
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/about_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/error_feedback_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/video_settings_content.dart';
import '../../helpers/l10n_delegates.dart' show l10nDelegates;

/// 设置面板拆分后的层/分区装配 — 缺服务时的回落与单订阅契约.
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  Widget subject({SettingsServicesBundle? services}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: l10nDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 330,
          child: SettingsPanel(
            visible: true,
            onClose: () {},
            services: services,
          ),
        ),
      ),
    ),
  );

  testWidgets('empty bundle: audio tag enters L1 but shows no audio content', (
    tester,
  ) async {
    await tester.pumpWidget(subject(services: const SettingsServicesBundle()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-tab-audio')));
    await tester.pumpAndSettle();

    // 缺 settings 服务 — 回落空视图而非伪造内容（无 `!` 崩溃）.
    expect(find.byType(AudioSettingsContent), findsNothing);
    expect(find.byType(VideoSettingsContent), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about tag renders AboutContent without any services', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-tab-about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutContent), findsOneWidget);
  });

  testWidgets('general L1 subscribes ErrorFeedbackSettingsData exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-tab-general')));
    await tester.pumpAndSettle();

    expect(find.byType(GeneralSettingsContent), findsOneWidget);
    // 语言行 + 错误卡片开关行共用同一层订阅（此前各订阅一次）.
    expect(
      find.byType(ValueListenableBuilder<ErrorFeedbackSettingsData>),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('language-menu-trigger')), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('keyboard: down then right enters the selected section', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    // 面板聚焦后 ↓ 移到 about 之后保持（enabled 集合内到头即停），→ 进入 L1.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.byType(AboutContent), findsOneWidget);
  });
}
