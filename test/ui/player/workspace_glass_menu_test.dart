import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(focused?.color, Tokens.surfaceHighlight);
    expect(
      focused?.border,
      isNull,
      reason: 'focus uses solid background, no accent outline',
    );
    expect(idle?.color, Colors.transparent);
    expect(idle?.border, isNull);
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('First'), matching: find.byType(InkWell)),
    );
    // hover 跟随鼠标(2026-10-09 裁决) — hover 色与键盘焦点高亮统一为
    // surfaceHighlight, 消除"hover 亮/键盘暗"的视觉倒挂(桌面菜单惯例).
    expect(ink.hoverColor, Tokens.surfaceHighlight);
    expect(ink.hoverColor, focused?.color);
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
      // 原 GlassMenu 门面（已删除）的 legacy 重绑序列，手动复现：
      // open(useWorkspaceScope:false) → onOpened 同步 claim ownership →
      // 把新 token 绑回本 route。
      final handle = OwnedAnchoredMenu.open<String>(
        context,
        owner: 'legacy',
        useWorkspaceScope: false,
        position: Offset.zero,
        entries: const [
          OwnedMenuEntry(value: 'play', label: 'Legacy', icon: Icons.play_arrow),
        ],
      );
      menus.open(
        owner: 'legacy',
        cancel: handle.cancel,
        isCurrent: () => ModalRoute.of(context)?.isCurrent == true,
        onEscape: () {
          menus.cancel();
          exits++;
        },
      );
      final claimed = menus.currentToken;
      if (claimed != null) {
        menus.bindRoute(claimed, handle.route, ModalRoute.of(context));
      }
      final result = handle.result.then((r) => r?.value);
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
    final result = OwnedAnchoredMenu.open<String>(
      context,
      owner: Object(),
      position: const Offset(799, 599),
      entries: const [
        OwnedMenuEntry(value: 'play', label: 'Play', icon: Icons.play_arrow),
        OwnedMenuEntry(
          value: 'remove',
          label: 'Remove',
          icon: Icons.delete,
          isDestructive: true,
        ),
      ],
    ).result.then((r) => r?.value);
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
    final old = OwnedAnchoredMenu.open<String>(
      context,
      owner: Object(),
      useWorkspaceScope: false,
      position: Offset.zero,
      entries: const [
        OwnedMenuEntry(value: 'old', label: 'Old', icon: Icons.play_arrow),
      ],
    );
    VoidCallback? closeOld = old.cancel;
    final oldResult = old.result.then((r) => r?.value);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    closeOld?.call();
    await tester.pumpAndSettle();
    expect(await oldResult, isNull);
    final next = OwnedAnchoredMenu.open<String>(
      context,
      owner: Object(),
      useWorkspaceScope: false,
      position: const Offset(100, 100),
      entries: const [
        OwnedMenuEntry(value: 'next', label: 'Next', icon: Icons.play_arrow),
      ],
    ).result.then((r) => r?.value);
    await tester.pumpAndSettle();
    closeOld?.call();
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(await next, isNull);
  });
}
