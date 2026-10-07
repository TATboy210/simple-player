import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/player/modal_hold_observer.dart';

void main() {
  testWidgets('owned dropdown restores actual trigger not ancestor scope', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final actualTrigger = FocusNode(debugLabel: 'real-language-trigger');
    addTearDown(menus.dispose);
    addTearDown(actualTrigger.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [ModalHoldObserver()],
        home: WorkspaceMenuScope(
          session: menus,
          onEscape: () {},
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                focusNode: actualTrigger,
                child: const Text('sort'),
                onPressed: () {
                  showMenu<int>(
                    context: context,
                    position: RelativeRect.fill,
                    items: const [PopupMenuItem(value: 1, child: Text('one'))],
                  );
                  WorkspaceMenuScope.maybeOf(context)?.ownLatestRoute(
                    context,
                    'sort',
                    triggerFocus: actualTrigger,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sort'));
    await tester.pumpAndSettle();
    menus.cancel();
    await tester.pumpAndSettle();
    expect(actualTrigger.hasPrimaryFocus, isTrue);
  });
}
