/// GeneralSettingsContent 通用设置行的行为测试（SET-01/03 UI 收口，G-04-1 后形态）。
///
/// Behavioral tests for the general settings rows after the G-04-1 removal:
/// the error-card toggle (flip-then-persist) is the only row, and the removed
/// log-path surface (input field / browse button / validation status /
/// effective-path line) is asserted absent (G-04-1 UI 面，UAT Test 3/5 对应
/// 自动化证据).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/diagnostic_log_target.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/error_feedback_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';

void main() {
  late Directory root;
  late File settingsFile;
  late DelegatingDiagnosticLogEffect delegate;
  late File activeFile;

  // 固定中文 locale —— 断言文案不随宿主环境漂移。
  Widget buildSubject() {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 320,
          child: GeneralSettingsContent(),
        ),
      ),
    );
  }

  /// 交替推进 fake 微任务与真实 I/O 直到 [condition] 成立。
  ///
  /// widget 测试的 FakeAsync zone 不派发真实文件事件：pump 冲刷 fake 微任务
  /// （推进持久化链的续体），runAsync 窗口放行真实 I/O 完成事件。
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) {
        await tester.pump();
        return;
      }
      await tester.pump(const Duration(milliseconds: 5));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    fail('condition not met after 100 pump cycles');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('general-content-');
    addTearDown(() async {
      try {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      } on FileSystemException {
        // 清理失败不致命（OS 兜底回收）：fire-and-forget 持久化的未完成
        // 写句柄可能短暂占用临时目录，不阻塞测试判定。
      }
    });
    // store seam 指向用例临时 settings.json，避免触碰真实设置（04-03 惯例）。
    settingsFile = File(
      '${root.path}${Platform.pathSeparator}settings.json',
    );
    ErrorFeedbackSettings.I.resetForTesting(settingsFile: () => settingsFile);
    addTearDown(() => ErrorFeedbackSettings.I.resetForTesting());
    // 协调器重绑：真实 delegate + 临时落点（04-02 测试惯例）。provider 形参
    // 已随 G-04-1 重定向面移除，resetForTesting 只重绑 effect 缝。
    delegate = DelegatingDiagnosticLogEffect();
    final activeDir =
        Directory('${root.path}${Platform.pathSeparator}active')..createSync();
    activeFile = File(
      '${activeDir.path}${Platform.pathSeparator}'
      '${ErrorLogLocation.logFileName}',
    );
    DiagnosticLogTarget.I.resetForTesting(effect: delegate);
    DiagnosticLogTarget.I.activateResolved(file: activeFile);
    // dispose 的内部 await 链（drain）在 body 结束后的 teardown 阶段无 pump
    // 推进 —— FakeAsync 微任务饥饿会让 await 永不完成（10 分钟超时实证）。
    // fire-and-forget：dispose 的同步段立即复位 activate 一次性锁与 notifier，
    // sink 不持 OS 句柄，残余链无害；下一用例 setUp 的 resetForTesting 重绑。
    addTearDown(() => unawaited(delegate.dispose()));
    addTearDown(() => ErrorFeedbackSettings.I.resetForTesting());
  });

  testWidgets('toggle row flips the store and persists to settings.json', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    // 初始 Switch 为开（store 默认 true）。
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(ErrorFeedbackSettings.I.state.value.errorCardEnabled, isFalse);

    // fire-and-forget 持久化可观测：临时 settings.json 已被写入 false。
    await pumpUntil(tester, () => settingsFile.existsSync());
    final persisted = await tester.runAsync(
      () => settingsFile.readAsString(),
    );
    expect(persisted, contains('"errorCardEnabled":false'));

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(ErrorFeedbackSettings.I.state.value.errorCardEnabled, isTrue);
  });

  testWidgets('general tab renders the toggle row only; the removed log-path '
      'surface is absent (G-04-1)', (tester) async {
    await tester.pumpWidget(buildSubject());

    // 路径配置面整体缺席（G-04-1）：文本输入框 / 浏览按钮 / 行内校验状态 /
    // 有效路径行在任何形态下都不渲染。
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('settings-log-path-browse')), findsNothing);
    expect(find.text('校验中…'), findsNothing);
    expect(find.text('目录可写'), findsNothing);
    expect(find.text('无法写入该目录'), findsNothing);
    expect(find.text('无法打开目录选择器'), findsNothing);
    expect(find.textContaining('当前有效路径'), findsNothing);

    // 开关行仍是唯一设置行且行为不变：翻转置 store 并可等待持久化
    //（pendingPersist 等待点经 runAsync 放行真实 I/O，见 04-04 协议）。
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(ErrorFeedbackSettings.I.state.value.errorCardEnabled, isFalse);
    await tester.runAsync(() => ErrorFeedbackSettings.I.pendingPersist);
    final persisted = await tester.runAsync(
      () => settingsFile.readAsString(),
    );
    expect(persisted, contains('"errorCardEnabled":false'));
  });
}
