import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';
import 'package:simple_player_flutter/ui/player/modal_hold_observer.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/workspace_focus_scope.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

void main() {
  for (final injected in [false, true]) {
    testWidgets('empty controls session=$injected retains route-local dispatch', (
      tester,
    ) async {
      final engine = FakeEngine();
      final video = FakeVideoControlsPort();
      final menus = WorkspaceMenuSession();
      final title = ValueNotifier('a.mp4');
      final mode = ValueNotifier(WindowMode.windowed);
      final navigator = GlobalKey<NavigatorState>();
      var playerCalls = 0;
      addTearDown(engine.dispose);
      addTearDown(video.dispose);
      for (final source in [menus, title, mode]) {
        addTearDown(source.dispose);
      }
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerVideoControls(
              video: video,
              engine: engine,
              actions: PlayerActions(
                onPlayPause: () => playerCalls++,
                onSeekBack: (_) => playerCalls++,
                onSeekForward: (_) => playerCalls++,
              ),
              currentFileName: title,
              windowMode: mode,
              menuSession: injected ? menus : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final local = tester
          .widgetList<Focus>(
            find.descendant(
              of: find.byType(PlayerVideoControls),
              matching: find.byType(Focus),
            ),
          )
          .firstWhere((focus) => focus.autofocus && focus.onKeyEvent != null);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(playerCalls, 1, reason: 'current-route controls dispatch once');
      final source = ModalRoute.of(
        tester.element(find.byType(PlayerVideoControls)),
      );
      unawaited(
        navigator.currentState?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Text('fullscreen-page'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(source?.isCurrent, isFalse);
      expect(menus.currentToken, isNull);
      // Invoke the real retained controls boundary explicitly: no new input or
      // fullscreen feature is implied by preserving its pre-session semantics.
      for (final key in [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        expect(
          local.onKeyEvent?.call(
            local.focusNode ?? FocusManager.instance.rootScope,
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: key,
              timeStamp: Duration.zero,
            ),
          ),
          KeyEventResult.handled,
        );
      }
      expect(playerCalls, 4);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final teardown in ['none', 'video', 'host']) {
    testWidgets(
      'real owned menu ESC order and keyup/repeat teardown=$teardown',
      (tester) async {
        final engine = FakeEngine();
        final video = FakeVideoControlsPort();
        final menus = WorkspaceMenuSession();
        final title = ValueNotifier('a.mp4');
        final mode = ValueNotifier(WindowMode.fullscreen);
        final hostVisible = ValueNotifier(true);
        final order = <String>[];
        var playerCalls = 0;
        var outerExit = 0;
        addTearDown(engine.dispose);
        addTearDown(video.dispose);
        for (final source in [menus, title, mode, hostVisible]) {
          addTearDown(source.dispose);
        }
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: KeyboardHandler(
                menuSession: menus,
                onPlayPause: () => playerCalls++,
                onExitFullscreen: () => outerExit++,
                child: ValueListenableBuilder<bool>(
                  valueListenable: hostVisible,
                  builder: (_, visible, _) => visible
                      ? PlayerVideoControls(
                          video: video,
                          engine: engine,
                          actions: PlayerActions(
                            onPlayPause: () => playerCalls++,
                            onSeekBack: (_) => playerCalls++,
                            onSeekForward: (_) => playerCalls++,
                            onToggleFullscreen: () {
                              expect(menus.currentToken, isNull);
                              expect(video.exitFullscreenCallCount, 0);
                              order.add('host');
                              if (teardown == 'video') video.isMounted = false;
                              if (teardown == 'host') hostVisible.value = false;
                              mode.value = WindowMode.windowed;
                            },
                          ),
                          currentFileName: title,
                          windowMode: mode,
                          menuSession: menus,
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final trigger = tester.element(find.byType(PlayerVideoControls));
        final scope = WorkspaceMenuScope.maybeOf(trigger);
        // Scope wraps descendants, not the PlayerVideoControls element itself.
        final scoped = tester.widget<WorkspaceMenuScope>(
          find.byType(WorkspaceMenuScope),
        );
        expect(scope, isNull);
        final handle = OwnedAnchoredMenu.open(
          trigger,
          owner: Object(),
          session: menus,
          onEscape: scoped.onEscape,
          entries: const [OwnedMenuEntry(value: 'a', label: 'Real action')],
        );
        await tester.pumpAndSettle();
        final controlsFocus = tester
            .widgetList<Focus>(
              find.descendant(
                of: find.byType(PlayerVideoControls),
                matching: find.byType(Focus),
              ),
            )
            .firstWhere((focus) => focus.autofocus && focus.onKeyEvent != null);
        // Exercise the actual controls-local callback even if focus is stranded.
        for (final key in [
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.keyF,
        ]) {
          final result = controlsFocus.onKeyEvent?.call(
            controlsFocus.focusNode ?? FocusManager.instance.rootScope,
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: key,
              timeStamp: Duration.zero,
            ),
          );
          expect(result, KeyEventResult.ignored);
        }
        expect(playerCalls, 0);
        expect(order, isEmpty);
        menus.addListener(() {
          if (menus.currentToken == null) order.add('cancel');
        });
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        // Repeat and keyup of the same press must never exit a second time.
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(await handle.result, isNull);
        expect(order, ['cancel', 'host']);
        expect(outerExit, 0);
        expect(video.exitFullscreenCallCount, teardown == 'video' ? 0 : 1);
        expect(playerCalls, 0);
      },
    );
  }
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
    'control-bar settings button close restores focus through registry',
    (tester) async {
      final engine = FakeEngine()..state.value = MediaState.playing;
      final video = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
      );
      final workspace = PanelWorkspaceController()..toggle('settings');
      final title = ValueNotifier('a.mp4');
      final mode = ValueNotifier(WindowMode.windowed);
      final session = SettingsPanelSession();
      addTearDown(engine.dispose);
      addTearDown(video.dispose);
      addTearDown(workspace.dispose);
      addTearDown(title.dispose);
      addTearDown(mode.dispose);
      addTearDown(session.dispose);
      // 生产接线镜像 (player_screen.dart:205): 按钮回调即 workspace.toggle;
      // settingsVisible 传 null — workspace 是显隐唯一权威。
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
              actions: PlayerActions(
                onOpenSettings: () =>
                    workspace.toggle(WorkspaceTaskIds.settings),
              ),
              currentFileName: title,
              windowMode: mode,
              settingsVisible: null,
              workspace: workspace,
              settingsSession: session,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // (1) 前置条件 — 焦点先安置进设置面板 task scope。
      final registry = WorkspaceFocusScope.maybeOf(
        tester.element(find.byType(SettingsPanel)),
      );
      expect(
        registry,
        isNotNull,
        reason: 'workspace host must expose registry',
      );
      final taskScope = registry?.tasks[WorkspaceTaskIds.settings];
      expect(taskScope, isNotNull, reason: 'settings task scope registered');
      taskScope?.requestFocus();
      await tester.pump();
      // FocusScopeNode.requestFocus() 在 scope 已有 focusedChild 时会下放
      // 给 focusedChild(面板 initState 自动聚焦过 SettingsPanel 节点) —
      // 故"焦点在面板内"的判据是 primaryFocus 为 task scope 本身或其后代。
      final primary = FocusManager.instance.primaryFocus;
      final insidePanel =
          primary != null &&
          (identical(primary, taskScope) ||
              primary.ancestors.contains(taskScope));
      expect(
        insidePanel,
        isTrue,
        reason: 'precondition: focus lives inside the settings task scope',
      );
      // (2) 经控制栏设置按钮触发 toggle 关闭方向。
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      // (3) 关闭方向 — 快照已关, 焦点须归还 settings trigger(有效控件);
      // 修复前快照直改无归还, 焦点跌落路由 scope, 此断言必失败 (RED)。
      expect(workspace.value.hasTasks, isFalse);
      final restored = FocusManager.instance.primaryFocus;
      expect(
        identical(restored, registry?.triggers[WorkspaceTaskIds.settings]),
        isTrue,
        reason:
            'button-close must restore focus to the settings trigger, '
            'not strand it on the route dead-key scope',
      );
      expect(restored?.context, isNotNull);
      expect(restored?.canRequestFocus, isTrue);
      // (4) 打开方向回归 — 同一按钮再按一次, 面板重开, 显隐路径未变。
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(workspace.value.center, WorkspaceTaskIds.settings);
    },
  );

  testWidgets(
    'actual language ESC preserves owned route but unrelated dialog dismisses',
    (tester) async {
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      ModalHoldObserver.resetForTesting();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [ModalHoldObserver()],
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {},
            child: const Scaffold(body: GeneralSettingsContent()),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('language-menu-trigger')));
      await tester.pumpAndSettle();
      expect(menus.value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('日本語'), findsOneWidget);
      final dialog = showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('unrelated help')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await dialog;
      expect(find.text('unrelated help'), findsNothing);
      expect(find.text('日本語'), findsOneWidget);
      menus.cancel();
      await tester.pumpAndSettle();
      expect(find.text('日本語'), findsNothing);
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
