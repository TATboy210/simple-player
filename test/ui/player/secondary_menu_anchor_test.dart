import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';

/// Expose inherited listener state without violating protected Flutter APIs.
class _VisibilityProbe extends ValueNotifier<bool> {
  _VisibilityProbe() : super(true);

  bool get retainsListeners => hasListeners;
}

void main() {
  testWidgets('actual sort anchor follows retained panel movement', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final offset = ValueNotifier(20.0);
    final entries = ValueNotifier(const <PlaylistItem>[]);
    final current = ValueNotifier(-1);
    final last = ValueNotifier<String?>(null);
    final mode = ValueNotifier(PlayMode.loopAll);
    for (final source in [menus, offset, entries, current, last, mode]) {
      addTearDown(source.dispose);
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WorkspaceMenuScope(
          session: menus,
          onEscape: () {},
          child: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: offset,
              builder: (_, left, _) => Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 30,
                    width: 280,
                    height: 350,
                    child: PlaylistPanel(
                      entries: entries,
                      currentIndex: current,
                      lastPlayedPath: last,
                      visible: true,
                      onClose: () {},
                      onPlayEntry: (_) {},
                      onResumeEntry: (_) {},
                      onRemoveEntry: (_) {},
                      playMode: mode,
                      onCyclePlayMode: () {},
                      sortKey: PlaylistSortKey.addedOrder,
                      sortAscending: true,
                      onSortSelected: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byType(SecondarySurface));
    offset.value = 120;
    await tester.pump();
    await tester.pump();
    expect(
      tester.getRect(find.byType(SecondarySurface)).left - before.left,
      closeTo(100, 1),
    );
    menus.cancel();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'actual language trigger follows live movement and viewport resize',
    (tester) async {
      final menus = WorkspaceMenuSession();
      final offset = ValueNotifier(20.0);
      addTearDown(menus.dispose);
      addTearDown(offset.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(854, 480);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {},
            child: Scaffold(
              body: ValueListenableBuilder<double>(
                valueListenable: offset,
                builder: (_, left, _) => Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 30,
                      width: 400,
                      height: 200,
                      child: const GeneralSettingsContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('language-menu-trigger')));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(SecondarySurface));
      offset.value = 120;
      await tester.pump();
      await tester.pump();
      final after = tester.getRect(find.byType(SecondarySurface));
      expect(after.left - before.left, closeTo(100, 1));
      tester.view.physicalSize = const Size(620, 480);
      await tester.pump();
      await tester.pump();
      final clamped = tester.getRect(find.byType(SecondarySurface));
      expect(clamped.right, lessThanOrEqualTo(620));
      expect(
        find.descendant(
          of: find.byType(SecondarySurface),
          matching: find.text('日本語'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      menus.cancel();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('disposed borrowed session rejects opener without listeners', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession()..dispose();
    final visible = _VisibilityProbe();
    final focus = FocusNode(debugLabel: 'rejected-trigger');
    addTearDown(visible.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextButton(
            focusNode: focus,
            onPressed: () {},
            child: const Text('trigger'),
          ),
        ),
      ),
    );
    final handle = OwnedAnchoredMenu.open(
      tester.element(find.text('trigger')),
      owner: Object(),
      session: menus,
      visibility: visible,
      triggerFocus: focus,
      entries: const [OwnedMenuEntry(value: 'a', label: 'Rejected')],
    );
    var completed = false;
    Object? selection;
    unawaited(
      handle.result.then((value) {
        completed = true;
        selection = value;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsNothing);
    expect(handle.route.navigator, isNull);
    expect(completed, isTrue);
    expect(selection, isNull);
    expect(await handle.route.popped, isNull);
    expect(visible.retainsListeners, isFalse);
    expect(focus.hasPrimaryFocus, isFalse);
    expect(menus.owns(handle.token), isFalse);
    handle.cancel();
    menus.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous open cancellation never mounts orphan route', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final visible = _VisibilityProbe();
    addTearDown(menus.dispose);
    addTearDown(visible.dispose);
    menus.addListener(() {
      if (menus.value) menus.cancel();
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final handle = OwnedAnchoredMenu.open(
      tester.element(find.byType(Scaffold)),
      owner: Object(),
      session: menus,
      visibility: visible,
      entries: const [OwnedMenuEntry(value: 'a', label: 'Canceled')],
    );
    var completed = false;
    unawaited(handle.result.then((_) => completed = true));
    await tester.pumpAndSettle();
    expect(find.text('Canceled'), findsNothing);
    expect(handle.route.navigator, isNull);
    expect(completed, isTrue);
    expect(visible.retainsListeners, isFalse);
    expect(menus.currentToken, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous replacement leaves only new token route mounted', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final oldVisible = _VisibilityProbe();
    final newVisible = _VisibilityProbe();
    addTearDown(menus.dispose);
    addTearDown(oldVisible.dispose);
    addTearDown(newVisible.dispose);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final trigger = tester.element(find.byType(Scaffold));
    OwnedMenuHandle<String>? replacement;
    var isReplacing = false;
    menus.addListener(() {
      if (!menus.value || isReplacing) return;
      isReplacing = true;
      replacement = OwnedAnchoredMenu.open(
        trigger,
        owner: 'new',
        session: menus,
        visibility: newVisible,
        entries: const [OwnedMenuEntry(value: 'new', label: 'New')],
      );
    });
    final old = OwnedAnchoredMenu.open(
      trigger,
      owner: 'old',
      session: menus,
      visibility: oldVisible,
      entries: const [OwnedMenuEntry(value: 'old', label: 'Old')],
    );
    var completed = false;
    unawaited(old.result.then((_) => completed = true));
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsNothing);
    expect(find.text('New'), findsOneWidget);
    expect(old.route.navigator, isNull);
    expect(completed, isTrue);
    expect(oldVisible.retainsListeners, isFalse);
    final current = replacement;
    expect(current, isNotNull);
    if (current == null) return;
    expect(menus.owns(current.token), isTrue);
    old.cancel();
    await tester.pump();
    expect(find.text('New'), findsOneWidget);
    expect(menus.owns(current.token), isTrue);
    current.cancel();
    await tester.pumpAndSettle();
    expect(await current.result, isNull);
    expect(newVisible.retainsListeners, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live button follows movement resize and cancels disposed owner',
    (tester) async {
      final menus = WorkspaceMenuSession();
      final visible = ValueNotifier(true);
      final x = ValueNotifier(40.0);
      final retained = ValueNotifier(true);
      addTearDown(menus.dispose);
      addTearDown(visible.dispose);
      addTearDown(x.dispose);
      addTearDown(retained.dispose);
      final triggerKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySurfaceVisibility(
              visibility: visible,
              child: ValueListenableBuilder(
                valueListenable: retained,
                builder: (_, keep, _) => keep
                    ? ValueListenableBuilder(
                        valueListenable: x,
                        builder: (_, left, _) => Stack(
                          children: [
                            Positioned(
                              left: left,
                              top: 50,
                              child: SizedBox(
                                key: triggerKey,
                                width: 80,
                                height: 30,
                                child: const Text('trigger'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ),
        ),
      );
      final trigger = triggerKey.currentContext;
      expect(trigger, isNotNull);
      if (trigger == null) return;
      final handle = OwnedAnchoredMenu.open(
        trigger,
        owner: Object(),
        session: menus,
        entries: const [OwnedMenuEntry(value: 'a', label: 'Action')],
      );
      await tester.pumpAndSettle();
      final original = tester.getRect(find.byType(SecondarySurface));
      expect(original.left, 40);
      expect(original.top, 80);
      x.value = 140;
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(find.byType(SecondarySurface)).left, 140);
      tester.view.physicalSize = const Size(200, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SecondarySurface)).right,
        lessThanOrEqualTo(200),
      );
      retained.value = false;
      await tester.pump();
      expect(menus.isOwnedMenuTopmost, isFalse);
      await tester.pumpAndSettle();
      expect(await handle.result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'build hide invalidates synchronously and defers route teardown',
    (tester) async {
      final menus = WorkspaceMenuSession();
      final visible = ValueNotifier(true);
      final hide = ValueNotifier(false);
      addTearDown(menus.dispose);
      addTearDown(visible.dispose);
      addTearDown(hide.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: hide,
              builder: (_, shouldHide, _) {
                if (shouldHide) visible.value = false;
                return const Text('trigger');
              },
            ),
          ),
        ),
      );
      final handle = OwnedAnchoredMenu.open(
        tester.element(find.text('trigger')),
        owner: Object(),
        session: menus,
        visibility: visible,
        entries: const [OwnedMenuEntry(value: 'a', label: 'Action')],
      );
      await tester.pumpAndSettle();
      hide.value = true;
      await tester.pump();
      expect(menus.isOwnedMenuTopmost, isFalse);
      await tester.pumpAndSettle();
      expect(await handle.result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('tiny viewport keeps complete labels scroll reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(180, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    final result = GlassMenu.show(
      context,
      position: const Offset(400, 400),
      items: List.generate(
        8,
        (i) => GlassMenuItem(
          Icons.language,
          'Complete long language label $i',
          value: '$i',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(SecondarySurface));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(180));
    expect(rect.bottom, lessThanOrEqualTo(120));
    final text = tester.widget<Text>(
      find.text('Complete long language label 7'),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    await tester.scrollUntilVisible(
      find.text('Complete long language label 7'),
      70,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Complete long language label 7'));
    await tester.pumpAndSettle();
    expect(await result, '7');
  });
}
