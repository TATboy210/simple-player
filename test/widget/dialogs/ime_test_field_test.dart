import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/ime_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/ime_test_field.dart';

/// ImeTestField 焦点启停接线契约 (v0.0.8.2) —
/// 聚焦 → enable (wparam=1 恢复默认 IMC)；失焦 → disable (wparam=0 再解除)。
/// 这是未来正式输入框的同款接线验证 (防 flutter/flutter#78796)。
void main() {
  setUpAll(() {
    // 桥内部走 KernelLogger (项目惯例: 测试显式初始化).
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late List<int> wparams;
  late Win32ImeBridge bridge;

  setUp(() {
    wparams = [];
    bridge = Win32ImeBridge(
      functions: Win32ImeFunctions(
        findWindow: (_) => 0x42,
        sendMessageTimeout: (_, _, wparam, _, _) {
          wparams.add(wparam);
          return true;
        },
      ),
    );
  });

  Future<void> pumpField(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              ImeTestField(bridge: bridge),
              // 焦点转移目标 — 点击使测试框失焦 (Flutter 点击非焦点区
              // 不自动失焦, 必须转移到另一个可聚焦件).
              const SizedBox(height: 40),
              const TextField(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('聚焦 — 投递 enable (wparam=1)', (tester) async {
    await pumpField(tester);
    expect(wparams, isEmpty, reason: '未聚焦不投递');

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(wparams, [1], reason: '聚焦恢复默认 IMC — 中文可组合');
  });

  testWidgets('聚焦后失焦 — 投递 disable (wparam=0), 启停配对', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    // 点击第二个输入框 — 焦点转移, 测试框失焦.
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();

    expect(wparams, [1, 0], reason: '启停无条件配对 — 失焦再解除');
  });

  testWidgets('组件卸载时仍持焦点 — dispose 兜底 disable', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(wparams, [1]);

    // 卸载组件 (仍持焦点) — dispose 兜底解除防 IME 状态泄漏.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(wparams, [1, 0], reason: 'dispose 兜底 disable');
  });

  testWidgets('失焦配对后再卸载 — 无冗余第三条消息 (_hadFocus 复位语义)', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(wparams, [1, 0]);

    // 失焦已复位 _hadFocus — 卸载不得重发 disable.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(wparams, [1, 0], reason: '冗余 disable = 原生侧幂等但语义含混');
  });
}
