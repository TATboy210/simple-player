import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';

void main() {
  testWidgets('菜单内连续 Tab 首尾回绕，焦点永不越出菜单 route', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final menu = harness.open(tester);
    await tester.pumpAndSettle();
    expect(
      _focusLabel(),
      'owned-menu-First',
      reason: '打开菜单后首启用行应获得初始聚焦',
    );
    // 期望序列：First → Last（跳过禁用行）→ 回绕 First → 再回绕 Last。
    const expectedStops = [
      'owned-menu-Last',
      'owned-menu-First',
      'owned-menu-Last',
    ];
    for (final expected in expectedStops) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        menu.route.isCurrent,
        isTrue,
        reason: 'Tab 移动后菜单 route 必须保持 current',
      );
      expect(
        _focusLabel(),
        expected,
        reason: '连续 Tab 应在启用行间首尾回绕（跳过禁用行），绝不越出菜单 route',
      );
    }
    menu.cancel();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Shift+Tab 自首行反向回绕到末行，不越出 route', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final menu = harness.open(tester);
    await tester.pumpAndSettle();
    expect(
      _focusLabel(),
      'owned-menu-First',
      reason: '打开菜单后首启用行应获得初始聚焦',
    );
    // Shift+Tab 三段式发键：keyDown shift → tab → keyUp shift。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      menu.route.isCurrent,
      isTrue,
      reason: 'Shift+Tab 反向移动后菜单 route 必须保持 current',
    );
    expect(
      _focusLabel(),
      'owned-menu-Last',
      reason: 'Shift+Tab 应从首行回绕到末启用行，而不是越出菜单 route 落到播放器侧',
    );
    menu.cancel();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('焦点在菜单内时 Tab 不触发播放器快捷键', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final menu = harness.open(tester);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      harness.playerCalls,
      0,
      reason: '菜单开着时 Tab 被焦点陷阱吞掉，绝不触发播放器 playPause',
    );
    expect(
      _focusLabel(),
      startsWith('owned-menu-'),
      reason: 'Tab 后焦点必须仍停留在菜单行节点上',
    );
    expect(
      menu.route.isCurrent,
      isTrue,
      reason: '菜单 route 必须保持 current',
    );
    menu.cancel();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// 当前主焦点节点的 debugLabel；菜单行节点以 owned-menu- 前缀公开可断言。
String? _focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

/// 真实 KeyboardHandler + owned PopupRoute；计数的是生产回调边界。
/// 与 secondary_menu_keyboard_test 同形，另把 Tab 绑定为 playPause，
/// 使"菜单内 Tab 不触发播放器快捷键"断言真实生效。
class _Harness {
  final menus = WorkspaceMenuSession();
  final external = FocusNode(debugLabel: 'external-player-focus');
  int playerCalls = 0;

  void _act() => playerCalls++;

  Widget build() => MaterialApp(
    builder: (_, child) => Focus(focusNode: external, child: child!),
    home: Scaffold(
      body: KeyboardHandler(
        menuSession: menus,
        customBindings: {'playPause': LogicalKeyboardKey.tab.keyId.toString()},
        onPlayPause: _act,
        onSeekBackward: _act,
        onSeekForward: _act,
        onVolumeUp: _act,
        onVolumeDown: _act,
        onToggleMute: _act,
        onOpenFile: _act,
        onToggleSubtitle: _act,
        onTogglePlaylist: _act,
        onPlayPrevious: _act,
        onPlayNext: _act,
        onToggleFullscreen: _act,
        onShowHelp: _act,
        onSubtitleDelayForward: _act,
        onSubtitleDelayBackward: _act,
        onMediaPlayPause: _act,
        onExitFullscreen: _act,
        child: const Text('trigger'),
      ),
    ),
  );

  OwnedMenuHandle<String> open(WidgetTester tester) => OwnedAnchoredMenu.open(
    tester.element(find.text('trigger')),
    owner: this,
    session: menus,
    onEscape: () {},
    entries: const [
      OwnedMenuEntry(value: 'first', label: 'First'),
      OwnedMenuEntry(value: 'disabled', label: 'Disabled', isEnabled: false),
      OwnedMenuEntry(value: 'last', label: 'Last'),
    ],
  );

  void dispose() {
    menus.dispose();
    external.dispose();
  }
}
