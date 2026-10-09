import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';

void main() {
  testWidgets('Tab and reverse Tab traverse enabled menu rows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('trigger'))),
    );
    final menu = OwnedAnchoredMenu.open<String>(
      tester.element(find.text('trigger')),
      owner: Object(),
      entries: const [
        OwnedMenuEntry(value: 'first', label: 'First'),
        OwnedMenuEntry(value: 'disabled', label: 'Disabled', isEnabled: false),
        OwnedMenuEntry(value: 'last', label: 'Last'),
      ],
    );
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-First');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-Last');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-First');
    final enabled = tester.widget<InkWell>(
      find.ancestor(of: find.text('First'), matching: find.byType(InkWell)),
    );
    final disabled = tester.widget<InkWell>(
      find.ancestor(of: find.text('Disabled'), matching: find.byType(InkWell)),
    );
    expect(enabled.mouseCursor, SystemMouseCursors.click);
    expect(disabled.mouseCursor, SystemMouseCursors.basic);
    menu.cancel();
    await tester.pumpAndSettle();
  });
}
