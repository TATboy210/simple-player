import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';

void main() {
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
