import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';
import 'package:simple_player_flutter/ui/player/modal_hold_observer.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

void main() {
  for (final invalidatesVideo in [false, true]) {
    testWidgets(
      'owned menu ESC invokes host before guarded video exit $invalidatesVideo',
      (tester) async {
        final engine = FakeEngine();
        final video = FakeVideoControlsPort();
        final workspace = PanelWorkspaceController()..toggle('settings');
        final title = ValueNotifier('a.mp4');
        final mode = ValueNotifier(WindowMode.fullscreen);
        final menus = WorkspaceMenuSession();
        addTearDown(engine.dispose);
        for (final source in [workspace, title, mode, menus]) {
          addTearDown(source.dispose);
        }
        addTearDown(video.dispose);
        final order = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlayerVideoControls(
              video: video,
              engine: engine,
              actions: PlayerActions(
                onToggleFullscreen: () {
                  expect(menus.value, isFalse);
                  expect(video.exitFullscreenCallCount, 0);
                  order.add('host');
                  if (invalidatesVideo) video.isMounted = false;
                },
              ),
              currentFileName: title,
              windowMode: mode,
              workspace: workspace,
              menuSession: menus,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(SettingsPanel));
        final scope = WorkspaceMenuScope.maybeOf(context);
        expect(scope, isNotNull);
        menus.open(
          owner: Object(),
          cancel: () => order.add('cancel'),
          isCurrent: () => true,
          onEscape: scope?.onEscape,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(order, ['cancel', 'host']);
        expect(video.exitFullscreenCallCount, invalidatesVideo ? 0 : 1);
        expect(workspace.value.center, 'settings');
      },
    );
  }
  for (final hasLegacySeam in [false, true]) {
    testWidgets(
      'ESC keeps task, blank closes task and hold releases legacy=$hasLegacySeam',
      (tester) async {
        final engine = FakeEngine()..state.value = MediaState.playing;
        final video = FakeVideoControlsPort(
          player: FakePlayerControls(isPlayingNow: true),
        );
        final workspace = PanelWorkspaceController()..toggle('settings');
        final visible = ValueNotifier(true);
        final title = ValueNotifier('a.mp4');
        final mode = ValueNotifier(WindowMode.windowed);
        final menus = WorkspaceMenuSession();
        final session = SettingsPanelSession();
        addTearDown(engine.dispose);
        addTearDown(video.dispose);
        addTearDown(workspace.dispose);
        addTearDown(visible.dispose);
        addTearDown(title.dispose);
        addTearDown(mode.dispose);
        addTearDown(menus.dispose);
        addTearDown(session.dispose);
        // A stale legacy seam must be ignored when workspace is authoritative.
        visible.value = false;
        await tester.binding.setSurfaceSize(const Size(854, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PlayerVideoControls(
                video: video,
                engine: engine,
                actions: const PlayerActions(),
                currentFileName: title,
                windowMode: mode,
                settingsVisible: hasLegacySeam ? visible : null,
                workspace: workspace,
                settingsSession: session,
                menuSession: menus,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(SettingsPanel)).width, 280);
        await tester.pump(const Duration(seconds: 6));
        expect(
          tester
              .widget<Visibility>(
                find.byKey(const Key('player-controls-visibility')),
              )
              .visible,
          isTrue,
          reason: 'Workspace alone holds playing controls',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(workspace.value.center, 'settings');
        await tester.tapAt(const Offset(30, 30));
        await tester.pumpAndSettle();
        expect(workspace.value.hasTasks, isFalse);
        expect(visible.value, isFalse);
      },
    );
  }

  testWidgets(
    'Dropdown ESC preserves owned route but unrelated dialog dismisses',
    (tester) async {
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      ModalHoldObserver.resetForTesting();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [ModalHoldObserver()],
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {},
            child: Scaffold(
              body: Builder(
                builder: (context) => DropdownButton<int>(
                  value: 1,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('one')),
                    DropdownMenuItem(value: 2, child: Text('two')),
                  ],
                  onTap: () =>
                      WorkspaceMenuScope.maybeOf(context)
                          ?.ownLatestRoute(context, 'language'),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      expect(menus.value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      final dialog = showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('unrelated help')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await dialog;
      expect(find.text('unrelated help'), findsNothing);
      expect(find.text('two'), findsOneWidget);
      menus.cancel();
      await tester.pumpAndSettle();
      expect(find.text('two'), findsNothing);
      expect(ModalHoldObserver.openModalCount.value, 0);
    },
  );

  testWidgets('menu exact removal precedes fullscreen exit without task loss', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final workspace = PanelWorkspaceController()..toggle('settings');
    addTearDown(menus.dispose);
    addTearDown(workspace.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('window')),
      ),
    );
    final full = MaterialPageRoute<void>(
      builder: (_) => const Text('fullscreen'),
    );
    unawaited(navigator.currentState!.push(full));
    await tester.pumpAndSettle();
    final popup = DialogRoute<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('menu'),
    );
    unawaited(navigator.currentState!.push(popup));
    menus.open(
      owner: 'sort',
      cancel: () => navigator.currentState!.removeRoute(popup),
      isCurrent: () => popup.isCurrent,
      onEscape: () {
        menus.cancel();
        expect(full.isCurrent, isTrue);
        navigator.currentState!.pop();
      },
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('window'), findsOneWidget);
    expect(find.text('menu'), findsNothing);
    expect(workspace.value.center, 'settings');
  });
}
