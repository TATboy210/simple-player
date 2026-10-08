import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';

void main() {
  for (final reverse in [false, true]) {
    testWidgets(
      'hardware handlers share canceled event identity order $reverse',
      (tester) async {
        final menus = WorkspaceMenuSession();
        addTearDown(menus.dispose);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('trigger'))),
        );
        final handle = OwnedAnchoredMenu.open(
          tester.element(find.text('trigger')),
          owner: Object(),
          session: menus,
          entries: const [OwnedMenuEntry(value: 'a', label: 'Action')],
        );
        await tester.pumpAndSettle();
        var firstGuarded = 0;
        var secondGuarded = 0;
        bool first(KeyEvent event) {
          if (event is KeyDownEvent && menus.guardsPlayerEvent(event)) {
            firstGuarded++;
            handle.cancel();
          }
          return true; // This must NOT stop another HardwareKeyboard handler.
        }

        bool second(KeyEvent event) {
          if (event is KeyDownEvent && menus.guardsPlayerEvent(event)) {
            secondGuarded++;
            handle.cancel();
          }
          return false;
        }

        final handlers = reverse ? [second, first] : [first, second];
        for (final handler in handlers) {
          HardwareKeyboard.instance.addHandler(handler);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        for (final handler in handlers) {
          HardwareKeyboard.instance.removeHandler(handler);
        }
        await tester.pumpAndSettle();
        expect(firstGuarded, 1);
        expect(secondGuarded, 1);
        expect(await handle.result, isNull);
      },
    );
  }

  testWidgets('superseded completion cannot restore old trigger focus', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final firstFocus = FocusNode(debugLabel: 'first-trigger');
    final nextFocus = FocusNode(debugLabel: 'next-trigger');
    addTearDown(menus.dispose);
    addTearDown(firstFocus.dispose);
    addTearDown(nextFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: firstFocus, child: const Text('first')),
              Focus(focusNode: nextFocus, child: const Text('next')),
            ],
          ),
        ),
      ),
    );
    final old = OwnedAnchoredMenu.open(
      tester.element(find.text('first')),
      owner: Object(),
      session: menus,
      triggerFocus: firstFocus,
      entries: const [OwnedMenuEntry(value: 'a', label: 'Old')],
    );
    await tester.pumpAndSettle();
    final next = OwnedAnchoredMenu.open(
      tester.element(find.text('next')),
      owner: Object(),
      session: menus,
      triggerFocus: nextFocus,
      entries: const [OwnedMenuEntry(value: 'b', label: 'New')],
    );
    await tester.pumpAndSettle();
    expect(await old.result, isNull);
    expect(firstFocus.hasPrimaryFocus, isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-New');
    old.cancel();
    expect(menus.owns(next.token), isTrue);
    next.cancel();
    await tester.pumpAndSettle();
    expect(nextFocus.hasPrimaryFocus, isTrue);
    expect(firstFocus.hasPrimaryFocus, isFalse);
  });
  testWidgets('exact route guards same event but yields foreign top dialog', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final visible = ValueNotifier(true);
    final focus = FocusNode(debugLabel: 'actual-trigger');
    addTearDown(menus.dispose);
    addTearDown(visible.dispose);
    addTearDown(focus.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Focus(focusNode: focus, child: const Text('trigger')),
        ),
      ),
    );
    final trigger = tester.element(find.text('trigger'));
    final owner = Object();
    final handle = OwnedAnchoredMenu.open(
      trigger,
      owner: owner,
      session: menus,
      visibility: visible,
      triggerFocus: focus,
      entries: const [OwnedMenuEntry(value: 'a', label: 'Action')],
    );
    await tester.pumpAndSettle();
    expect(menus.isOwnedMenuTopmost, isTrue);
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: LogicalKeyboardKey.enter,
      timeStamp: Duration.zero,
    );
    expect(menus.guardsPlayerEvent(event), isTrue);
    handle.cancel();
    expect(menus.isOwnedMenuTopmost, isFalse);
    expect(menus.guardsPlayerEvent(event), isTrue);
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    final next = OwnedAnchoredMenu.open(
      trigger,
      owner: owner,
      session: menus,
      visibility: visible,
      triggerFocus: focus,
      entries: const [OwnedMenuEntry(value: 'b', label: 'Next')],
    );
    await tester.pumpAndSettle();
    final dialog = DialogRoute<void>(
      context: trigger,
      builder: (_) => const AlertDialog(content: Text('foreign')),
    );
    navigator.currentState?.push(dialog);
    await tester.pumpAndSettle();
    expect(menus.isOwnedMenuTopmost, isFalse);
    expect(menus.guardsPlayerEvent(event), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('foreign'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    visible.value = false;
    expect(menus.isOwnedMenuTopmost, isFalse);
    await tester.pumpAndSettle();
    expect(await next.result, isNull);
  });

  testWidgets('disabled nodes skipped checked action remains selectable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('trigger'))),
    );
    final trigger = tester.element(find.text('trigger'));
    final handle = OwnedAnchoredMenu.open(
      trigger,
      owner: Object(),
      entries: const [
        OwnedMenuEntry(
          value: 'checked',
          label: 'Checked sort',
          isChecked: true,
        ),
        OwnedMenuEntry(value: 'disabled', label: 'Disabled', isEnabled: false),
        OwnedMenuEntry(value: 'last', label: 'Last'),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'owned-menu-Checked sort',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-Last');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'owned-menu-Checked sort',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect((await handle.result)?.value, 'checked');
  });
  testWidgets(
    'replacement ignores stale finish and disposed open cancels once',
    (tester) async {
      final menus = WorkspaceMenuSession();
      var oldCancels = 0;
      var newCancels = 0;
      final oldOwner = Object();
      final newOwner = Object();
      final old = menus.open(
        owner: oldOwner,
        cancel: () => oldCancels++,
        isCurrent: () => true,
      );
      menus.open(
        owner: newOwner,
        cancel: () => newCancels++,
        isCurrent: () => true,
      );
      expect(oldCancels, 1);
      menus.finish(old);
      menus.cancelOwner(oldOwner);
      expect(menus.value, isTrue);
      expect(newCancels, 0);
      menus.cancelOwner(newOwner);
      expect(newCancels, 1);
      expect(menus.value, isFalse);
      menus.dispose();
      menus.dispose();
      menus.open(
        owner: Object(),
        cancel: () => newCancels++,
        isCurrent: () => true,
      );
      expect(newCancels, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(newCancels, 2);
    },
  );
  testWidgets(
    'scoped menu ESC preserves route and cancel removes exact route',
    (tester) async {
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('player')),
        ),
      );
      final route = DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('owned menu'),
      );
      final done = navigator.currentState!.push(route);
      menus.open(
        owner: 'sort',
        cancel: () => navigator.currentState!.removeRoute(route),
        isCurrent: () => route.isCurrent,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('owned menu'), findsOneWidget);
      expect(menus.value, isTrue);
      expect(menus.cancel(), isTrue);
      await tester.pumpAndSettle();
      await done;
      expect(find.text('owned menu'), findsNothing);
      expect(menus.value, isFalse);
      expect(menus.cancel(), isFalse);
    },
  );

  test('media-independent sessions survive media invalidation', () {
    final menus = WorkspaceMenuSession();
    addTearDown(menus.dispose);
    var canceled = 0;
    menus.open(
      owner: 'language',
      cancel: () => canceled++,
      isCurrent: () => true,
    );
    menus.mediaChanged('new');
    expect(canceled, 0);
    menus.open(
      owner: 'entry',
      mediaIdentity: 'old',
      cancel: () => canceled++,
      isCurrent: () => true,
    );
    menus.mediaChanged('new');
    expect(canceled, 2); // replacing language + invalidating old-media entry
    expect(menus.value, isFalse);
  });
}
