// SpinControl 集成测试 — 覆盖 GeneralTab 中 SpinControl 的集成行为。
//
// 验证：SpinControl 在 GeneralTab 中正确渲染、PendingSettingsState 数据流。
// 焦点/点击行为已由 spin_control_test.dart 覆盖，此处专注数据集成。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/pending_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/general_tab.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  /// 最小化测试壳 — MaterialApp + PendingSettingsState 包裹 GeneralTab。
  Future<PendingSettingsState> pumpGeneralTab(WidgetTester tester) async {
    final pending = PendingSettingsState()
      ..register('locale', 'zh')
      ..register('darkMode', true);
    addTearDown(pending.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GeneralTab(pending: pending)),
        ),
      ),
    );
    return pending;
  }

  group('SpinControl integration in GeneralTab', () {
    testWidgets('SpinControl renders for locale selection', (tester) async {
      // Arrange & Act
      await pumpGeneralTab(tester);

      // Assert — SpinControl 存在于 GeneralTab 中
      expect(find.byType(SpinControl), findsOneWidget);

      // Assert — 默认显示 '中文'（locale='zh'，formatValue 生效）
      expect(find.text('中文'), findsOneWidget);
    });

    testWidgets('SpinControl renders with correct boundary arrow colors', (
      tester,
    ) async {
      // Arrange & Act — 默认 index=0（左边界）
      await pumpGeneralTab(tester);

      // Assert — 左箭头灰色（边界），右箭头正常色
      final leftIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(leftIcon.color, Tokens.textTertiary);
      final rightIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(rightIcon.color, Tokens.textSecondary);
    });

    testWidgets(
      'SpinControl has formatValue that maps locale to display text',
      (tester) async {
        // Arrange & Act — 当前 locale='zh'，formatValue 应映射为 '中文'
        await pumpGeneralTab(tester);

        // Assert — 显示 '中文' 而非 'zh'
        expect(find.text('中文'), findsOneWidget);
        expect(find.text('zh'), findsNothing);
      },
    );

    testWidgets('GeneralTab contains language and dark mode settings', (
      tester,
    ) async {
      // Arrange & Act
      await pumpGeneralTab(tester);

      // Assert — 语言部分
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('界面语言'), findsOneWidget);
      expect(find.text('选择界面显示语言'), findsOneWidget);

      // Assert — 外观部分
      expect(find.text('外观'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);

      // Assert — SpinControl 和 Switch 都存在
      expect(find.byType(SpinControl), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('SettingSpinRow wraps SpinControl inside SettingRow', (
      tester,
    ) async {
      // Arrange & Act
      await pumpGeneralTab(tester);

      // Assert — SettingSpinRow 是 GeneralTab 渲染的公开包装组件
      expect(find.byType(SettingSpinRow), findsOneWidget);

      // Assert — SpinControl 位于 SettingRow 内（真实组合关系，而非
      // AnimatedContainer 这类实现细节）
      final settingRowFinder = find.ancestor(
        of: find.byType(SpinControl),
        matching: find.byType(SettingRow),
      );
      expect(settingRowFinder, findsOneWidget);

      // Assert — SettingRow 的 control 槽位即 SpinControl（验证
      // SettingSpinRow -> SettingRow(control: SpinControl) 接线契约）
      final settingRow = tester.widget<SettingRow>(settingRowFinder);
      expect(settingRow.control, isA<SpinControl>());

      // Assert — SettingSpinRow 把 title/description/icon 透传给 SettingRow
      expect(settingRow.title, '界面语言');
      expect(settingRow.description, '选择界面显示语言');
      expect(settingRow.icon, Icons.language);

      // Assert — 内嵌 SpinControl 携带 locale 选项与当前索引
      final spinControl = tester.widget<SpinControl>(find.byType(SpinControl));
      expect(spinControl.options, ['zh', 'en']);
      expect(spinControl.currentIndex, 0); // locale='zh' -> index 0
    });
  });
}
