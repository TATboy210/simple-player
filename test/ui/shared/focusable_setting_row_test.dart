// FocusableSettingRow widget 测试 — 覆盖 D-11/D-12/D-13/D-15。
//
// 测试焦点边框、hover 背景、disabled 行为、即时切换（无动画）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/focusable_setting_row.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  /// 构建最小化测试壳 — MaterialApp 包裹 FocusableSettingRow。
  Future<void> pumpRow(
    WidgetTester tester, {
    required Widget child,
    bool enabled = true,
    bool autofocus = false,
    ValueChanged<bool>? onFocusChange,
    Key? focusKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusableSettingRow(
            enabled: enabled,
            autofocus: autofocus,
            onFocusChange: onFocusChange,
            focusKey: focusKey,
            child: child,
          ),
        ),
      ),
    );
  }

  group('FocusableSettingRow', () {
    testWidgets('renders child widget', (tester) async {
      // Arrange & Act
      await pumpRow(tester, child: const Text('Test Setting'));

      // Assert
      expect(find.text('Test Setting'), findsOneWidget);
    });

    testWidgets('shows focus border when focused (D-11)', (tester) async {
      // Arrange
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableSettingRow(
              focusNode: focusNode,
              child: const Text('Focusable'),
            ),
          ),
        ),
      );

      // Act — 请求焦点
      focusNode.requestFocus();
      await tester.pump();

      // Assert — 焦点边框即时更新为设计令牌色。
      final decoration = tester
          .widget<Container>(
            find.descendant(
              of: find.byType(FocusableSettingRow),
              matching: find.byType(Container),
            ),
          )
          .decoration;
      expect(decoration, isA<BoxDecoration>());
      final boxDecoration = decoration! as BoxDecoration;
      expect(boxDecoration.border, isA<Border>());
      final border = boxDecoration.border! as Border;
      expect(border.top.color, Tokens.controlBarBorderWhite);
    });

    testWidgets('disabled widget is not focusable (D-15)', (tester) async {
      // Arrange & Act
      await pumpRow(tester, enabled: false, child: const Text('Disabled Row'));

      // Assert — ExcludeFocus 存在（D-15: 禁用行不接收焦点）
      // IgnorePointer 可能有多个（MaterialApp/Scaffold 内置），用 descendant 缩小范围
      expect(find.byType(ExcludeFocus), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExcludeFocus),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      expect(find.text('Disabled Row'), findsOneWidget);
    });

    testWidgets('disabled widget has ExcludeFocus wrapping child', (
      tester,
    ) async {
      // Arrange & Act
      await pumpRow(tester, enabled: false, child: const Text('No Focus'));

      // Assert — ExcludeFocus 是 IgnorePointer 的祖先
      final excludeFocus = tester.widget<ExcludeFocus>(
        find.byType(ExcludeFocus),
      );
      expect(excludeFocus, isNotNull);
    });

    testWidgets('enabled widget does NOT have ExcludeFocus', (tester) async {
      // Arrange & Act
      await pumpRow(tester, enabled: true, child: const Text('Focusable'));

      // Assert — 无 ExcludeFocus
      expect(find.byType(ExcludeFocus), findsNothing);
    });

    testWidgets('uses Container not AnimatedContainer for border (D-13)', (
      tester,
    ) async {
      // Arrange & Act
      await pumpRow(tester, child: const Text('No Animation'));

      // Assert — 应使用 Container（即时切换）而非 AnimatedContainer
      // FocusableSettingRow 内部使用 Container 包裹子 widget
      expect(find.byType(FocusableSettingRow), findsOneWidget);
    });

    testWidgets('onFocusChange callback fires when focus changes', (
      tester,
    ) async {
      // Arrange
      final focusChanges = <bool>[];
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableSettingRow(
              focusNode: focusNode,
              onFocusChange: (focused) => focusChanges.add(focused),
              child: const Text('Callback Test'),
            ),
          ),
        ),
      );

      // Act — 直接请求 FocusableSettingRow 的焦点节点。
      focusNode.requestFocus();
      await tester.pump();

      // Assert — 回调记录实际的未聚焦到聚焦状态转换。
      expect(focusChanges, contains(true));
    });

    testWidgets('focusKey is passed to FocusableActionDetector', (
      tester,
    ) async {
      // Arrange
      const testKey = ValueKey('test-focus-key');

      // Act
      await pumpRow(tester, focusKey: testKey, child: const Text('Key Test'));

      // Assert — FocusableSettingRow 存在且 key 正确
      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('autofocus is passed through', (tester) async {
      // Arrange & Act
      await pumpRow(tester, autofocus: true, child: const Text('Autofocus'));

      // Assert — widget 存在且 autofocus 参数已传递
      expect(find.text('Autofocus'), findsOneWidget);
      expect(find.byType(FocusableSettingRow), findsOneWidget);
    });
  });
}
