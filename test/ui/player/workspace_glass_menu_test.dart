import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// Inspect the actual row paint, not only its keyboard activation result.
BoxDecoration? rowDecoration(WidgetTester tester, String label) {
  final candidates = tester.widgetList<DecoratedBox>(
    find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)),
  );
  for (final box in candidates) {
    if (box.decoration case final BoxDecoration decoration) {
      if (decoration.borderRadius == BorderRadius.circular(Tokens.radiusBtn)) {
        return decoration;
      }
    }
  }
  return null;
}

/// Read the existing outer row focus node; no extra Tab stop is acceptable.
FocusNode? rowFocus(WidgetTester tester, String label) {
  for (final focus in tester.widgetList<Focus>(
    find.ancestor(of: find.text(label), matching: find.byType(Focus)),
  )) {
    if (focus.focusNode?.debugLabel == 'owned-menu-$label') {
      return focus.focusNode;
    }
  }
  return null;
}

void main() {
  testWidgets('painted keyboard focus moves and skips disabled checked rows', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final handle = OwnedAnchoredMenu.open(
      tester.element(find.byType(Scaffold)),
      owner: Object(),
      entries: const [
        OwnedMenuEntry(value: 'a', label: 'First'),
        OwnedMenuEntry(
          value: 'b',
          label: 'Disabled',
          isEnabled: false,
          isChecked: true,
        ),
        OwnedMenuEntry(value: 'c', label: 'Checked', isChecked: true),
      ],
    );
    await tester.pumpAndSettle();
    final focused = rowDecoration(tester, 'First');
    final idle = rowDecoration(tester, 'Checked');
    expect(focused, isNotNull);
    expect(idle, isNotNull);
    expect(focused?.color, Tokens.bgElevated);
    expect(focused?.border, Border.all(color: Tokens.accent));
    expect(idle?.color, Colors.transparent);
    expect(idle?.border, Border.all(color: Colors.transparent));
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('First'), matching: find.byType(InkWell)),
    );
    expect(ink.hoverColor, Tokens.bgHover);
    expect(ink.hoverColor, isNot(focused?.color));
    expect(ink.canRequestFocus, isFalse);
    expect(rowFocus(tester, 'First')?.hasPrimaryFocus, isTrue);
    expect(rowFocus(tester, 'Disabled')?.canRequestFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowDecoration(tester, 'First'), idle);
    expect(rowDecoration(tester, 'Checked'), focused);
    expect(rowDecoration(tester, 'Disabled'), idle);
    expect(rowFocus(tester, 'Checked')?.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rowDecoration(tester, 'First'), focused);
    expect(rowDecoration(tester, 'Checked'), idle);
    expect(rowFocus(tester, 'First')?.hasPrimaryFocus, isTrue);
    handle.cancel();
    await tester.pumpAndSettle();
    expect(await handle.result, isNull);
  });

  testWidgets(
    'legacy onOpened ownership is rebound exact and fullscreen exit cancels',
    (tester) async {
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {
              menus.cancel();
              exits++;
            },
            child: const Scaffold(body: Text('trigger')),
          ),
        ),
      );
      final context = tester.element(find.text('trigger'));
      final result = GlassMenu.show(
        context,
        position: Offset.zero,
        items: const [GlassMenuItem(Icons.play_arrow, 'Legacy', value: 'play')],
        onOpened: (cancel) => menus.open(
          owner: 'legacy',
          cancel: cancel,
          isCurrent: () => ModalRoute.of(context)?.isCurrent == true,
          onEscape: () {
            menus.cancel();
            exits++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(menus.isOwnedMenuTopmost, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(exits, 1);
      expect(menus.isOwnedMenuTopmost, isFalse);
    },
  );
  testWidgets('actual menu is opaque and arrows activate once', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    final result = GlassMenu.show(
      context,
      position: const Offset(799, 599),
      items: const [
        GlassMenuItem(Icons.play_arrow, 'Play', value: 'play'),
        GlassMenuItem(Icons.delete, 'Remove', value: 'remove'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(SecondarySurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    final rect = tester.getRect(find.byType(SecondarySurface));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(800));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, 'remove');
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('windowed escape preserves menu and outside cancel is exact', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    VoidCallback? closeOld;
    final old = GlassMenu.show(
      context,
      position: Offset.zero,
      items: const [GlassMenuItem(Icons.play_arrow, 'Old', value: 'old')],
      onOpened: (cancel) => closeOld = cancel,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    closeOld?.call();
    await tester.pumpAndSettle();
    expect(await old, isNull);
    final next = GlassMenu.show(
      context,
      position: const Offset(100, 100),
      items: const [GlassMenuItem(Icons.play_arrow, 'Next', value: 'next')],
    );
    await tester.pumpAndSettle();
    closeOld?.call();
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(await next, isNull);
  });
}
