import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/error_feedback_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';

import '../../helpers/fake_engine.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('entry-menus-');
    ErrorFeedbackSettings.I.resetForTesting(
      settingsFile: () => File('${directory.path}/settings.json'),
    );
    addTearDown(() async {
      ErrorFeedbackSettings.I.resetForTesting();
      await directory.delete(recursive: true);
    });
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'actual language row zero $key opens without player activation',
      (tester) async {
        final menus = WorkspaceMenuSession();
        final rows = FocusNode(debugLabel: 'actual-general-rows');
        addTearDown(menus.dispose);
        addTearDown(rows.dispose);
        var playerCalls = 0;
        await tester.pumpWidget(
          _app(
            menus,
            KeyboardHandler(
              menuSession: menus,
              onPlayPause: () => playerCalls++,
              child: GeneralSettingsContent(rowsFocusNode: rows),
            ),
          ),
        );
        rows.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(SecondarySurface), findsOneWidget);
        expect(menus.isOwnedMenuTopmost, isTrue);
        expect(playerCalls, 0);
        expect(
          ErrorFeedbackSettings.I.state.value.language,
          AppLanguage.system,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(
          ErrorFeedbackSettings.I.state.value.language,
          AppLanguage.english,
        );
        expect(playerCalls, 0);
        final trigger = tester.widget<TextButton>(
          find.byKey(const ValueKey('language-menu-trigger')),
        );
        expect(trigger.focusNode?.hasPrimaryFocus, isTrue);
        await _drainSettings(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'actual language focus $key reopens after row one pointer selection',
      (tester) async {
        final menus = WorkspaceMenuSession();
        final rows = FocusNode(debugLabel: 'nonzero-general-rows');
        addTearDown(menus.dispose);
        addTearDown(rows.dispose);
        var playerCalls = 0;
        await tester.pumpWidget(
          _app(
            menus,
            KeyboardHandler(
              menuSession: menus,
              onPlayPause: () => playerCalls++,
              child: GeneralSettingsContent(rowsFocusNode: rows),
            ),
          ),
        );
        rows.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.tap(find.byKey(const ValueKey('language-menu-trigger')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(SecondarySurface),
            matching: find.text('English'),
          ),
        );
        await tester.pumpAndSettle();
        final trigger = tester.widget<TextButton>(
          find.byKey(const ValueKey('language-menu-trigger')),
        );
        expect(trigger.focusNode?.hasPrimaryFocus, isTrue);
        final selected = ErrorFeedbackSettings.I.state.value;
        final persistence = ErrorFeedbackSettings.I.pendingPersist;
        expect(selected.language, AppLanguage.english);
        expect(selected.errorCardEnabled, isTrue);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        // Drain even the defective toggle's write before a RED assertion aborts
        // the test, so file cleanup cannot obscure the behavior failure.
        await _drainSettings(tester);
        expect(menus.isOwnedMenuTopmost, isTrue);
        expect(find.byType(SecondarySurface), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'owned-menu-English',
        );
        expect(ErrorFeedbackSettings.I.state.value, same(selected));
        expect(ErrorFeedbackSettings.I.pendingPersist, same(persistence));
        expect(playerCalls, 0);
        menus.cancel();
        await tester.pumpAndSettle();
        // A real arrow transfers focus away from the restored button; Enter then
        // activates the visibly highlighted row, not the language trigger.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(rows.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(menus.currentToken, isNull);
        expect(ErrorFeedbackSettings.I.state.value.errorCardEnabled, isFalse);
        expect(playerCalls, 0);
        await _drainSettings(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('all five actual language choices update same mounted store', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    addTearDown(menus.dispose);
    await tester.pumpWidget(_app(menus, const GeneralSettingsContent()));
    final element = tester.element(find.byType(GeneralSettingsContent));
    for (final choice in AppLanguage.values) {
      await tester.tap(find.byKey(const ValueKey('language-menu-trigger')));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<AppLanguage>), findsNothing);
      final label = switch (choice) {
        AppLanguage.system => 'Follow system',
        AppLanguage.english => 'English',
        AppLanguage.chinese => '中文',
        AppLanguage.korean => '한국어',
        AppLanguage.japanese => '日本語',
      };
      final menuText = find.descendant(
        of: find.byType(SecondarySurface),
        matching: find.text(label),
      );
      await tester.tap(menuText);
      await tester.pumpAndSettle();
      expect(ErrorFeedbackSettings.I.state.value.language, choice);
      expect(
        tester.element(find.byType(GeneralSettingsContent)),
        same(element),
      );
    }
    await _drainSettings(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'actual coordinator repeat current sort flips twice and restores trigger',
    (tester) async {
      final engine = FakeEngine();
      final coordinator = PlaylistCoordinator(engine: engine);
      final menus = WorkspaceMenuSession();
      final visible = ValueNotifier(true);
      addTearDown(engine.dispose);
      addTearDown(coordinator.dispose);
      addTearDown(menus.dispose);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        _app(
          menus,
          ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, shown, _) => SizedBox(
              height: 350,
              child: PlaylistPanel(
                entries: coordinator.entries,
                currentIndex: coordinator.currentIndex,
                lastPlayedPath: coordinator.lastPlayedPath,
                visible: shown,
                onClose: () {},
                onPlayEntry: (_) {},
                onResumeEntry: (_) {},
                onRemoveEntry: (_) {},
                playMode: coordinator.playMode,
                onCyclePlayMode: () {},
                sortKey: coordinator.sortKey,
                sortAscending: coordinator.sortAscending,
                onSortSelected: (key) async {
                  await coordinator.sortEntries(key);
                  visible.value = !visible.value;
                  visible.value = !visible.value;
                },
              ),
            ),
          ),
        ),
      );
      for (final ascending in [false, true]) {
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();
        expect(find.byType(SecondarySurface), findsOneWidget);
        final entry = find.descendant(
          of: find.byType(SecondarySurface),
          matching: find.textContaining('Added'),
        );
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(coordinator.sortAscending, ascending);
        final sort = tester.widget<GlassButton>(
          find.widgetWithIcon(GlassButton, Icons.sort),
        );
        expect(sort.focusNode?.hasPrimaryFocus, isTrue);
      }
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      final retained = tester.element(find.byType(PlaylistPanel));
      visible.value = false;
      await tester.pumpAndSettle();
      expect(menus.currentToken, isNull);
      expect(find.byType(SecondarySurface), findsNothing);
      expect(tester.element(find.byType(PlaylistPanel)), same(retained));
      await _drainSettings(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final hide in ['owner', 'layer', 'replace-source']) {
    testWidgets(
      'cached actual General menu cancels on $hide without cache loss',
      (tester) async {
        final menus = WorkspaceMenuSession();
        final visible = ValueNotifier(true);
        final source = ValueNotifier(true);
        final replacement = ValueNotifier(true);
        final sources = ValueNotifier(source);
        final session = SettingsPanelSession()..navigate('general', true);
        for (final notifier in [
          menus,
          visible,
          source,
          replacement,
          sources,
          session,
        ]) {
          addTearDown(notifier.dispose);
        }
        await tester.pumpWidget(
          _app(
            menus,
            ValueListenableBuilder<ValueNotifier<bool>>(
              valueListenable: sources,
              builder: (_, eligibility, _) => SecondarySurfaceVisibility(
                visibility: eligibility,
                child: ValueListenableBuilder<bool>(
                  valueListenable: visible,
                  builder: (_, shown, _) => SizedBox(
                    width: 500,
                    height: 400,
                    child: SettingsPanel(
                      visible: shown,
                      session: session,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-menu-trigger')));
        await tester.pumpAndSettle();
        expect(menus.currentToken, isNotNull);
        final general = tester.element(find.byType(GeneralSettingsContent));
        final cache = tester.widget(
          find.byKey(const ValueKey('settings-l1-boundary-general')),
        );
        if (hide == 'owner') visible.value = false;
        if (hide == 'layer') session.navigate('general', false);
        if (hide == 'replace-source') {
          sources.value = replacement;
          await tester.pump();
          source.value = false;
          await tester.pump();
          expect(
            menus.currentToken,
            isNotNull,
            reason: 'old source is detached',
          );
          replacement.value = false;
        }
        // L0 summary marquee repeats indefinitely in English; pump transition only.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(menus.currentToken, isNull);
        expect(find.byType(SecondarySurface), findsNothing);
        expect(
          tester.element(
            find.byType(GeneralSettingsContent, skipOffstage: false),
          ),
          same(general),
        );
        expect(
          tester.widget(
            find.byKey(
              const ValueKey('settings-l1-boundary-general'),
              skipOffstage: false,
            ),
          ),
          same(cache),
        );
        await _drainSettings(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

/// Drain real I/O and fake-zone continuations without awaiting a starved zone.
/// 预算 300×10ms=3s 真实时间——CI runner 五 job 并发时真实文件 I/O 可能远慢于
/// 本机, 旧预算 100×5ms≈500ms 在 windows runner 上实证不够(2026-10-09 CI)。
Future<void> _drainSettings(WidgetTester tester) async {
  var drained = false;
  unawaited(
    ErrorFeedbackSettings.I.pendingPersist.whenComplete(() => drained = true),
  );
  for (var attempt = 0; attempt < 300 && !drained; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    drained,
    isTrue,
    reason: 'settings persistence completes before cleanup',
  );
}

/// Real localized entry fixture, sharing the same production workspace session.
Widget _app(WorkspaceMenuSession menus, Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: WorkspaceMenuScope(
    session: menus,
    onEscape: () {},
    child: Scaffold(body: child),
  ),
);
