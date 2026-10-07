import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';

void main() {
  testWidgets(
    'replacement session follows new navigation and clamps restored offset',
    (tester) async {
      final first = SettingsPanelSession()..navigate('audio', true);
      final second = SettingsPanelSession()..navigate('unknown', true);
      second.recordScroll('about', 100000);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget subject(SettingsPanelSession session) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 400,
            height: 120,
            child: SettingsPanel(
              visible: true,
              onClose: () {},
              session: session,
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(first));
      await tester.pumpAndSettle();
      await tester.pumpWidget(subject(second));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-l1-boundary-about')),
        findsOneWidget,
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
      first.navigate('video', true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-l1-boundary-about')),
        findsOneWidget,
      );
      second.navigate('general', true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-l1-boundary-general')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'general section restores shared offset in fresh local controller',
    (tester) async {
      final session = SettingsPanelSession()..navigate('general', true);
      session.recordScroll('general', 35);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              width: 400,
              height: 100,
              child: SettingsPanel(
                visible: true,
                onClose: () {},
                session: session,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        35,
      );
    },
  );
  testWidgets(
    'new route-local settings restores shared layer section and scroll',
    (tester) async {
      final session = SettingsPanelSession();
      addTearDown(session.dispose);
      Widget subject(Key key) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 330,
              child: SettingsPanel(
                key: key,
                visible: true,
                onClose: () {},
                session: session,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(const ValueKey('window')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offset, greaterThan(0));
      await tester.pumpWidget(subject(const ValueKey('fullscreen')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-l1-boundary-about')),
        findsOneWidget,
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offset, 0.1),
      );
    },
  );
}
