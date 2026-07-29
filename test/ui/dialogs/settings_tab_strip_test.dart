// settings_tab_strip_test.dart — Phase 32 Plan 02 Task 1 (NAV-01) TabArrowButton 测试。
//
// Task 1 范围：TabArrowButton 隔离测试（渲染 RepaintBoundary + 方向图标、
// onTap 恰好触发一次）。compact-width 无溢出测试需 SettingsTabStrip 的
// 端帽组合（Plan 02 Task 2 引入 onPrevTab/onNextTab + Pattern 3 组合），
// 故推迟到 Task 2 在本文件追加（deviation —— 见 32-02-SUMMARY）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_arrow_button.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_strip.dart';

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

  group('SettingsTabStrip', () {
    testWidgets(
      'compact-width: 7 nav items + 2 end caps render without RenderFlex overflow',
      (tester) async {
        // Arrange — compact 模式 + 400px 面板宽（D-04 fallback 文档阈值：
        // 每 tab 内容 ~31px，"均衡器"3 字 ~42px 自然宽触发 FittedBox scaleDown，
        // 图标 20px 仍容纳不溢出）。端帽固定宽 36×2 在 Expanded 外，中间吸收剩余。
        final selectedTab = ValueNotifier<int>(0);
        // 计数端帽路由 —— truth 1: 左=prevTab, 右=nextTab (T-32-05: 同 controller 路径)。
        var prevCount = 0;
        var nextCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: SettingsTabStrip(
                  selectedTab: selectedTab,
                  onSelect: (_) {},
                  isCompact: true,
                  onPrevTab: () => prevCount++,
                  onNextTab: () => nextCount++,
                ),
              ),
            ),
          ),
        );

        // Act — 让首帧布局安定（overflow 若发生在此帧被框架捕获）。
        await tester.pump();

        // Assert — 无 RenderFlex overflow（端帽固定宽 + 中间 Expanded 吸收 +
        // D-04 FittedBox scaleDown 三重保护，NAV-01 端帽组合 Pitfall 4 缓解）。
        expect(tester.takeException(), isNull);

        // Assert — 端帽 ×2 + 导航项 ×7 全部渲染（组合完整性 sanity）。
        expect(find.byType(TabArrowButton), findsNWidgets(2));
        expect(find.byType(SettingsNavItem), findsNWidgets(7));

        // Assert — 端帽路由: 左端帽(prev) / 右端帽(next) 各触发一次 (truth 1, T-32-05)。
        await tester.tap(find.byType(TabArrowButton).first);
        await tester.pump();
        expect(prevCount, 1);
        expect(nextCount, 0);
        await tester.tap(find.byType(TabArrowButton).last);
        await tester.pump();
        expect(prevCount, 1);
        expect(nextCount, 1);

        selectedTab.dispose();
      },
    );
  });
}
