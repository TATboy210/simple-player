import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';

/// G-03-1 开发用错误注入入口（Ctrl+Shift+I，kDebugMode 门控）全链路验证。
///
/// 注入走真实链路：按键 → KeyboardHandler 分支 → ErrorReporterImpl.I
/// 公开 intake（reportPlatformSafely）→ FIFO → presentation →
/// ErrorCardHost → ErrorCard + 捕获徽标（ErrorCaptureSnapshot effect）。
/// 零旁路显示、零 forTesting 构造器（仅 setUp 复位单例属测试惯例）。
void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init（App 组合根需要它）。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // 注入分支经 ErrorReporterImpl.I 单例上报；每个测试重建单例，保证
    // FIFO/计数断言不跨测试泄漏。effects 与生产 main.dart 的 D-11 接线
    // 一致（reporter 既有 effects 缝 → ErrorCaptureSnapshot.I.record）。
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
  });

  // 挂载层语义副本（同 error_card_host_test.dart）：MaterialApp 挂生产
  // buildErrorCardMount，home 注入 KeyboardHandler（autofocus Focus 接收
  // 真实按键流）——不构造 MediaKitEngine/media_kit Player（headless
  // mdk.dll 预存失败基线）。
  Widget buildMountHarness() => const MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: KeyboardHandler(child: SizedBox.expand()),
    builder: buildErrorCardMount,
  );

  /// 提取合成 message 尾部的「#N」计数 —— 注入计数器是 KeyboardHandler 的
  /// static（debug 会话存活、跨测试不复位），断言递增必须用相对比较而非
  /// 绝对序号。
  int trailingInjectedCount(String message) {
    final digits = RegExp(r'#(\d+)$').firstMatch(message)?.group(1);
    if (digits == null) return 0;
    return int.tryParse(digits) ?? 0;
  }

  group('G-03-1 开发用错误注入（Ctrl+Shift+I）', () {
    testWidgets('combo press routes a synthetic error to the card', (
      tester,
    ) async {
      // Arrange：宿主挂载 + 首帧 post-frame flushPresentation（D-12 门）。
      await tester.pumpWidget(buildMountHarness());
      await tester.pump();

      // Act：依序按下 Ctrl、Shift、I —— HardwareKeyboard 修饰键状态由按键流
      // 驱动，与 keyboard_handler 的 isControlPressed/isShiftPressed 判定一致。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
      await tester.pump();

      // Assert：卡片恰好一张且显示合成消息 —— 按键 → intake → FIFO →
      // presentation → Host → Card 全真实链路。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('调试注入的合成错误'), findsOneWidget);
    });

    testWidgets('rapid double press yields two distinct reports', (
      tester,
    ) async {
      // Arrange：宿主就绪。
      await tester.pumpWidget(buildMountHarness());
      await tester.pump();

      // Act：按住 Ctrl+Shift 快速连按两次 I（间隔远小于 10s 去重窗；I 释放
      // 后再按，模拟连续两次真实敲击）。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
      await tester.pump();

      // Assert：两份独立报告 —— 计数后缀差异化 8 字段语义身份（message 不同，
      // 且第二条计数严格递增），绕过 reporter 的 _dedupeWindow 合并窗；
      // 各自 occurrenceCount == 1。
      final reports = ErrorReporterImpl.I.queuedReports;
      expect(reports.length, 2);
      expect(reports[0].message, contains('调试注入的合成错误 #'));
      expect(reports[1].message, contains('调试注入的合成错误 #'));
      expect(reports[0].message, isNot(reports[1].message));
      expect(
        trailingInjectedCount(reports[1].message),
        greaterThan(trailingInjectedCount(reports[0].message)),
      );
      expect(reports[0].occurrenceCount, 1);
      expect(reports[1].occurrenceCount, 1);
    });

    testWidgets('synthetic report carries real-chain source and severity', (
      tester,
    ) async {
      // Arrange：宿主就绪。
      await tester.pumpWidget(buildMountHarness());
      await tester.pump();

      // Act：组合键注入一次。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
      await tester.pump();

      // Assert：platformDispatcher 来源 + error 级 —— D-02：error 上常驻
      // 卡片，不走 warning OSD 分流。
      final report = ErrorReporterImpl.I.queuedReports.single;
      expect(report.source, ErrorSource.platformDispatcher);
      expect(report.severity, ErrorSeverity.error);
    });

    testWidgets('bare I press without modifiers never injects', (tester) async {
      // Arrange：宿主就绪。
      await tester.pumpWidget(buildMountHarness());
      await tester.pump();

      // Act：只按 I，无修饰键。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
      await tester.pump();

      // Assert：零注入、零卡片 —— 单键 I 无既有映射且不受注入分支影响。
      expect(ErrorReporterImpl.I.queuedReports, isEmpty);
      expect(find.byType(ErrorCard), findsNothing);
    });
  });
}
