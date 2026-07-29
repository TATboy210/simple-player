// settings_tab_strip_test.dart — Phase 32 Plan 02 Task 1 (NAV-01) TabArrowButton 测试。
//
// Task 1 范围：TabArrowButton 隔离测试（渲染 RepaintBoundary + 方向图标、
// onTap 恰好触发一次）。compact-width 无溢出测试需 SettingsTabStrip 的
// 端帽组合（Plan 02 Task 2 引入 onPrevTab/onNextTab + Pattern 3 组合），
// 故推迟到 Task 2 在本文件追加（deviation —— 见 32-02-SUMMARY）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_arrow_button.dart';

void main() {
  group('TabArrowButton', () {
    testWidgets(
        'renders chevron icon matching direction, wrapped in RepaintBoundary',
        (tester) async {
      // Arrange — 左端帽。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabArrowButton(isLeft: true, onTap: () {}),
          ),
        ),
      );

      // Assert — RepaintBoundary 包裹存在（Pitfall 5 隔离端帽重绘）。
      expect(
        find.descendant(
          of: find.byType(TabArrowButton),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      // Assert — 左端帽渲染 chevron_left，非 chevron_right。
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // Act — 换右端帽。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabArrowButton(isLeft: false, onTap: () {}),
          ),
        ),
      );

      // Assert — 右端帽渲染 chevron_right。
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('onTap invokes the provided callback exactly once',
        (tester) async {
      // Arrange — 计数回调。
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabArrowButton(
              isLeft: true,
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      // Act — 点击端帽。
      await tester.tap(find.byType(TabArrowButton));
      await tester.pump();

      // Assert — 回调恰好触发一次（T-32-05：端帽点击走 controller 路径）。
      expect(tapCount, 1);
    });
  });
}
