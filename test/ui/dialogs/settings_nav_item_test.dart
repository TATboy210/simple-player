// SettingsNavItem widget 测试 — 覆盖 SIDEBAR-02（纵向布局、hover、selected 状态）。
//
// 验证当前纵向 Column 布局（icon + label 纵排）、hover 背景、
// selected 左侧指示器、onTap 回调。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  /// 最小化测试壳 — Material + Directionality 包裹 SettingsNavItem。
  Future<void> pumpNavItem(
    WidgetTester tester, {
    required bool selected,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsNavItem(
            icon: Icons.tune,
            label: 'General',
            selected: selected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('SettingsNavItem', () {
    testWidgets('renders icon + label text', (tester) async {
      // Arrange & Act
      await pumpNavItem(tester, selected: false);

      // Assert — icon 和 label 均可见
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets(
      'layout is vertical Column (icon over label, not horizontal Row)',
      (tester) async {
        // Arrange & Act
        await pumpNavItem(tester, selected: false);

        // Assert — SettingsNavItem 内部使用 Column（icon 上、label 下纵排），
        // mainAxisSize=min + crossAxisAlignment=stretch 以撑满 tab 宽度
        final column = tester.widget<Column>(
          find.descendant(
            of: find.byType(SettingsNavItem),
            matching: find.byType(Column),
          ),
        );
        expect(column.mainAxisSize, MainAxisSize.min);
        expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);

        // 不存在 Row 横排布局（旧水平契约已废弃）
        expect(
          find.descendant(
            of: find.byType(SettingsNavItem),
            matching: find.byType(Row),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'selected=false shows transparent left indicator, selected=true shows accent',
      (tester) async {
        // Arrange — 未选中态
        await pumpNavItem(tester, selected: false);

        // Assert — AnimatedContainer 的左侧 border 应为 transparent
        final container1 = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration1 = container1.decoration! as BoxDecoration;
        final border1 = decoration1.border as Border;
        expect(border1.left.color, Colors.transparent);

        // Act — 切换到选中态
        await pumpNavItem(tester, selected: true);

        // Assert — 左侧 border 应为 accent
        final container2 = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration2 = container2.decoration! as BoxDecoration;
        final border2 = decoration2.border as Border;
        expect(border2.left.color, Tokens.accent);
      },
    );

    testWidgets('onTap callback fires when tapped', (tester) async {
      // Arrange
      var tapCount = 0;
      await pumpNavItem(tester, selected: false, onTap: () => tapCount++);

      // Act
      await tester.tap(find.byType(SettingsNavItem));

      // Assert
      expect(tapCount, 1);
    });

    testWidgets('hover shows bgHover background', (tester) async {
      // Arrange
      await pumpNavItem(tester, selected: false);

      // Act — hover 进入
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(SettingsNavItem)));
      await tester.pump();

      // Assert — 背景色应变为 bgHover
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Tokens.bgHover);

      await gesture.removePointer();
    });
  });
}
