// SpinControl widget 测试 — 覆盖 D-08/D-09/D-03/D-10。
//
// 验证：渲染当前值、箭头图标、边界变灰、点击增减、键盘 D-pad、
// formatValue 回调、空列表安全。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/spin_control.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  /// 最小化测试壳 — MaterialApp 包裹 SpinControl
  Future<void> pumpSpinControl(
    WidgetTester tester, {
    required List<String> options,
    required int currentIndex,
    required ValueChanged<int> onChanged,
    String Function(String)? formatValue,
    Key? focusKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpinControl(
            options: options,
            currentIndex: currentIndex,
            onChanged: onChanged,
            formatValue: formatValue,
            focusKey: focusKey,
          ),
        ),
      ),
    );
  }

  group('SpinControl', () {
    testWidgets('renders current value text', (tester) async {
      // Arrange & Act
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0,
        onChanged: (_) {},
      );

      // Assert — 当前值 'zh' 可见
      expect(find.text('zh'), findsOneWidget);
    });

    testWidgets('renders left and right arrow icons', (tester) async {
      // Arrange & Act
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0,
        onChanged: (_) {},
      );

      // Assert — 左右箭头图标存在
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('left arrow gray at index 0 (boundary, D-03)', (tester) async {
      // Arrange & Act — index=0 左边界
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0,
        onChanged: (_) {},
      );

      // Assert — 左箭头颜色为 textTertiary（灰色）
      final leftIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(leftIcon.color, Tokens.textTertiary);

      // Assert — 右箭头颜色为 textSecondary（正常色）
      final rightIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(rightIcon.color, Tokens.textSecondary);
    });

    testWidgets('right arrow gray at last index (boundary, D-03)', (
      tester,
    ) async {
      // Arrange & Act — index=1（最后一个）右边界
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 1,
        onChanged: (_) {},
      );

      // Assert — 右箭头颜色为 textTertiary（灰色）
      final rightIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(rightIcon.color, Tokens.textTertiary);

      // Assert — 左箭头颜色为 textSecondary（正常色）
      final leftIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(leftIcon.color, Tokens.textSecondary);
    });

    testWidgets('left arrow tap decrements index', (tester) async {
      // Arrange
      int? capturedIndex;
      await pumpSpinControl(
        tester,
        options: ['zh', 'en', 'ja'],
        currentIndex: 2,
        onChanged: (i) => capturedIndex = i,
      );

      // Act — 点击左箭头
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      // Assert — onChanged 被调用，index=1
      expect(capturedIndex, 1);
    });

    testWidgets('right arrow tap increments index', (tester) async {
      // Arrange
      int? capturedIndex;
      await pumpSpinControl(
        tester,
        options: ['zh', 'en', 'ja'],
        currentIndex: 0,
        onChanged: (i) => capturedIndex = i,
      );

      // Act — 点击右箭头
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // Assert — onChanged 被调用，index=1
      expect(capturedIndex, 1);
    });

    testWidgets('no-op when tapping gray arrow at boundary', (tester) async {
      // Arrange
      var callCount = 0;
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0, // 左边界
        onChanged: (_) => callCount++,
      );

      // Act — 点击左箭头（灰色，不应触发）
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      // Assert — onChanged 未被调用
      expect(callCount, 0);
    });

    testWidgets('ArrowLeft key decrements when focused (D-10)', (tester) async {
      // Arrange
      int? capturedIndex;
      await pumpSpinControl(
        tester,
        options: ['zh', 'en', 'ja'],
        currentIndex: 2,
        onChanged: (i) => capturedIndex = i,
        focusKey: const Key('spin-test'),
      );

      // Act — 聚焦 SpinControl（使用子 widget 的 context 获取 FocusNode）
      final childElement = tester.element(
        find.descendant(
          of: find.byKey(const Key('spin-test')),
          matching: find.byType(Row),
        ),
      );
      Focus.of(childElement).requestFocus();
      await tester.pump();

      // Act — 按 ArrowLeft
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Assert — onChanged 被调用，index=1
      expect(capturedIndex, 1);
    });

    testWidgets('ArrowRight key increments when focused (D-10)', (
      tester,
    ) async {
      // Arrange
      int? capturedIndex;
      await pumpSpinControl(
        tester,
        options: ['zh', 'en', 'ja'],
        currentIndex: 0,
        onChanged: (i) => capturedIndex = i,
        focusKey: const Key('spin-test'),
      );

      // Act — 聚焦 SpinControl（使用子 widget 的 context 获取 FocusNode）
      final childElement = tester.element(
        find.descendant(
          of: find.byKey(const Key('spin-test')),
          matching: find.byType(Row),
        ),
      );
      Focus.of(childElement).requestFocus();
      await tester.pump();

      // Act — 按 ArrowRight
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Assert — onChanged 被调用，index=1
      expect(capturedIndex, 1);
    });

    testWidgets('formatValue callback applied to display', (tester) async {
      // Arrange & Act
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0,
        onChanged: (_) {},
        formatValue: (v) => v == 'zh' ? '中文' : 'English',
      );

      // Assert — 显示格式化后的文本
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('zh'), findsNothing);
    });

    testWidgets('empty options list handled gracefully', (tester) async {
      // Arrange & Act — 空列表不应崩溃
      await pumpSpinControl(
        tester,
        options: [],
        currentIndex: 0,
        onChanged: (_) {},
      );

      // Assert — 组件存在，箭头图标存在
      expect(find.byType(SpinControl), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Assert — 两个箭头都是灰色（空列表 = 两边都是边界）
      final leftIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(leftIcon.color, Tokens.textTertiary);
      final rightIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(rightIcon.color, Tokens.textTertiary);
    });

    testWidgets('middle index has both arrows normal color', (tester) async {
      // Arrange & Act — index=1 在 ['zh', 'en', 'ja'] 中间
      await pumpSpinControl(
        tester,
        options: ['zh', 'en', 'ja'],
        currentIndex: 1,
        onChanged: (_) {},
      );

      // Assert — 两个箭头都不是灰色
      final leftIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(leftIcon.color, Tokens.textSecondary);
      final rightIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(rightIcon.color, Tokens.textSecondary);
    });

    testWidgets('focus border appears when focused', (tester) async {
      // Arrange
      await pumpSpinControl(
        tester,
        options: ['zh', 'en'],
        currentIndex: 0,
        onChanged: (_) {},
        focusKey: const Key('spin-focus'),
      );

      // Act — 聚焦（使用子 widget 的 context 获取 FocusNode）
      final childElement = tester.element(
        find.descendant(
          of: find.byKey(const Key('spin-focus')),
          matching: find.byType(Row),
        ),
      );
      Focus.of(childElement).requestFocus();
      await tester.pump();

      // Assert — Container 的边框变为 borderHighlight
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('spin-focus')),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border as Border?;
      expect(border?.top.color, Tokens.borderHighlight);
    });
  });
}
