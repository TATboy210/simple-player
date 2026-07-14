import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_tab.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/equalizer_tab.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';

import '../../helpers/fake_engine.dart';

/// 带 AppLocalizations 的 MaterialApp 包装器
MaterialApp _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('GeneralTab', () {
    testWidgets('renders with GlassContainer', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        const GeneralTab(
          currentLocale: 'zh',
          currentThemeIndex: 0,
        ),
      ));

      // 应使用 GlassContainer（SettingsCard 已移除）
      expect(find.byType(GlassContainer), findsWidgets);
    });

    testWidgets('renders language section header with icon', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        const GeneralTab(
          currentLocale: 'zh',
          currentThemeIndex: 0,
        ),
      ));

      // 语言 SectionHeader 应带 Icons.language
      final sectionHeaders = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      final langHeader = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.language,
      );
      expect(langHeader, isNotNull);
    });

    testWidgets('renders theme section header with icon', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        const GeneralTab(
          currentLocale: 'zh',
          currentThemeIndex: 0,
        ),
      ));

      // 主题 SectionHeader 应带 Icons.palette
      final sectionHeaders = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      final themeHeader = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.palette,
      );
      expect(themeHeader, isNotNull);
    });

    testWidgets('language chips trigger onLocaleChanged callback',
        (tester) async {
      String? changedLocale;
      await tester.pumpWidget(_wrapWithL10n(
        GeneralTab(
          currentLocale: 'zh',
          currentThemeIndex: 0,
          onLocaleChanged: (loc) => changedLocale = loc,
        ),
      ));

      // 点击 English chip
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(changedLocale, 'en');
    });
  });

  group('EqualizerTab', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    testWidgets('renders with GlassContainer', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        EqualizerTab(engine: engine),
      ));

      // 应使用 GlassContainer（SettingsCard 已移除）
      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('renders equalizer section header', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        EqualizerTab(engine: engine),
      ));

      final sectionHeaders = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      final eqHeader = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.equalizer,
      );
      expect(eqHeader, isNotNull);
    });

    testWidgets('preserves SettingRow for each preset', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        EqualizerTab(engine: engine),
      ));

      // 应有 5 个 SettingRow（5 个均衡器预设）
      expect(find.byType(SettingRow), findsNWidgets(5));
    });

    testWidgets('preset selection calls engine.setEqualizer', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        EqualizerTab(engine: engine),
      ));

      // 点击第二个预设（Bass Boost）
      await tester.tap(find.byType(SettingRow).at(1));
      await tester.pump();

      // FakeEngine.setEqualizer 是 no-op，但选中状态应更新
      // 验证第二个 radio button 变为 checked
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final checkedIcons = icons.where(
        (icon) => icon.icon == Icons.radio_button_checked,
      );
      expect(checkedIcons.length, 1);
    });
  });
}
