/// GeneralSettingsContent 通用设置行的行为测试（SET-01/02/03 UI 收口）。
///
/// Behavioral tests for the general settings rows: the error-card toggle
/// (flip-then-persist), the debounced log-directory input (validate → save →
/// apply, three-nos on failure, clear-to-default-chain), the browse gateway
/// seam (null-cancel ignored, backfill same chain), and the D-04 inline
/// effective-path / fallback-reason display.
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

  // 固定中文 locale —— 行内状态文案断言不随宿主环境漂移。
  Widget buildSubject({
    Duration debounceDuration = const Duration(milliseconds: 20),
    Future<String?> Function()? directoryPicker,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 320,
          child: GeneralSettingsContent(
            debounceDuration: debounceDuration,
            directoryPicker: directoryPicker,
          ),
        ),
      ),
    );
  }

  /// 交替推进 fake 微任务与真实 I/O 直到 [condition] 成立。
  ///
  /// widget 测试的 FakeAsync zone 不派发真实文件事件：pump 冲刷 fake 微任务
  /// （推进 coordinator 链的续体），runAsync 窗口放行真实 I/O 完成事件。
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
    // 协调器重绑：真实 delegate + 临时 exe/AS 目录（04-02 测试惯例），
    // 激活一个旧落点使 effectiveLogPath 有初值。
    delegate = DelegatingDiagnosticLogEffect();
    final activeDir =
        Directory('${root.path}${Platform.pathSeparator}active')..createSync();
    activeFile = File(
      '${activeDir.path}${Platform.pathSeparator}'
      '${ErrorLogLocation.logFileName}',
    );
    DiagnosticLogTarget.I.resetForTesting(
      effect: delegate,
      applicationSupportDirectory: () async =>
          Directory('${root.path}${Platform.pathSeparator}as'),
      executableDirectory: () =>
          Directory('${root.path}${Platform.pathSeparator}exe'),
    );
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

  testWidgets('debounced valid directory validates, saves, and retargets', (
    tester,
  ) async {
    final writable =
        Directory('${root.path}${Platform.pathSeparator}writable');
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextField), writable.path);
    // 防抖到期前零副作用：store 未保存、有效路径未变、状态未进校验中。
    await tester.pump(const Duration(milliseconds: 5));
    expect(ErrorFeedbackSettings.I.state.value.logDirectory, isEmpty);
    expect(DiagnosticLogTarget.I.effectiveLogPath.value, activeFile.path);
    expect(find.text('校验中…'), findsNothing);

    // 防抖到期 → 行内校验→保存→apply 全协议生效。
    await tester.pump(const Duration(milliseconds: 30));
    await pumpUntil(
      tester,
      () => DiagnosticLogTarget.I.effectiveLogPath.value != activeFile.path,
    );

    final expectedFile = '${writable.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}';
    expect(DiagnosticLogTarget.I.effectiveLogPath.value, expectedFile);
    // 校验通过即保存（D-03 discretion）。
    expect(ErrorFeedbackSettings.I.state.value.logDirectory, writable.path);
    // 行内状态：可写✓。
    expect(find.text('目录可写'), findsOneWidget);
  });

  testWidgets('invalid path shows inline failure without saving or retargeting', (
    tester,
  ) async {
    // 指向「文件」的路径 —— 目录 create 遇同名文件占据，探测必败。
    // 写文件用同步 I/O：testWidgets body 的 FakeAsync zone 不派发真实文件
    // 事件，await 真实 I/O 会永不完成（04-03 实证陷阱）。
    final fileAsPath = File('${root.path}${Platform.pathSeparator}plain.txt');
    fileAsPath.writeAsStringSync('x');
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextField), fileAsPath.path);
    await tester.pump(const Duration(milliseconds: 30));
    await pumpUntil(
      tester,
      () => find.text('无法写入该目录').evaluate().isNotEmpty,
    );

    // 三不：不保存 / 不重定向 / 行内✗；输入内容保留（用户可修正）。
    expect(ErrorFeedbackSettings.I.state.value.logDirectory, isEmpty);
    expect(DiagnosticLogTarget.I.effectiveLogPath.value, activeFile.path);
    expect(find.text(fileAsPath.path), findsOneWidget);
  });

  testWidgets('clearing the input restores the default chain', (tester) async {
    final writable =
        Directory('${root.path}${Platform.pathSeparator}custom');
    await tester.pumpWidget(buildSubject());

    // 先配置到自定义目录，再清空 → 应回默认链（'' = reset 语义）。
    // 第一段等待以「有效路径已换位」为准（swap 完成 = 链完全落定）——
    // store 先于 swap 更新，若在其间继续输入会与未完成的换位并发竞争。
    await tester.enterText(find.byType(TextField), writable.path);
    await tester.pump(const Duration(milliseconds: 30));
    await pumpUntil(
      tester,
      () => DiagnosticLogTarget.I.effectiveLogPath.value ==
          '${writable.path}${Platform.pathSeparator}'
          '${ErrorLogLocation.logFileName}',
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 30));
    // 条件以「链解析出的最终落点」为准 —— store=='' 同步先置，effective 换位
    // 完成才算提交链落定（避免 swap 未完成即返回的竞态）。
    await pumpUntil(
      tester,
      () => DiagnosticLogTarget.I.effectiveLogPath.value ==
          '${root.path}${Platform.pathSeparator}exe'
          '${Platform.pathSeparator}${ErrorLogLocation.logsDirectoryName}'
          '${Platform.pathSeparator}${ErrorLogLocation.logFileName}',
    );

    // 默认链解析：注入 exe 根（root/exe，校验时现场创建）logs/error.log。
    expect(
      DiagnosticLogTarget.I.effectiveLogPath.value,
      '${root.path}${Platform.pathSeparator}exe'
      '${Platform.pathSeparator}${ErrorLogLocation.logsDirectoryName}'
      '${Platform.pathSeparator}${ErrorLogLocation.logFileName}',
    );
  });

  testWidgets('browse cancel is ignored without side effects', (tester) async {
    await tester.pumpWidget(
      buildSubject(directoryPicker: () async => null),
    );
    final before = DiagnosticLogTarget.I.effectiveLogPath.value;

    await tester.tap(find.byKey(const ValueKey('settings-log-path-browse')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    // null ≠ 清空：无任何校验/保存/重定向副作用（Pitfall：null-cancel）。
    expect(DiagnosticLogTarget.I.effectiveLogPath.value, before);
    expect(ErrorFeedbackSettings.I.state.value.logDirectory, isEmpty);
    expect(find.text('校验中…'), findsNothing);
  });

  testWidgets('browse backfill runs the same validate-save-apply chain', (
    tester,
  ) async {
    final picked = Directory('${root.path}${Platform.pathSeparator}picked');
    await tester.pumpWidget(
      buildSubject(directoryPicker: () async => picked.path),
    );

    await tester.tap(find.byKey(const ValueKey('settings-log-path-browse')));
    // 回填立即出现在输入框（与手输同一防抖链路，尚未到期）。
    await tester.pump();
    expect(find.text(picked.path), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 30));
    final expectedFile = '${picked.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}';
    await pumpUntil(
      tester,
      () => DiagnosticLogTarget.I.effectiveLogPath.value == expectedFile,
    );
    expect(ErrorFeedbackSettings.I.state.value.logDirectory, picked.path);
    expect(find.text('目录可写'), findsOneWidget);
  });

  testWidgets('effective path and fallback reason are shown inline', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    // 模拟「配置层失败后的有效路径」：store 指向一个目录而有效落点不同。
    ErrorFeedbackSettings.I.setLogDirectory('Z:\\not\\a\\real\\directory');
    await tester.pump();

    // D-04 第一通道：当前有效路径常显 + 回退原因。
    // 完整行 = 标签 + 路径单匹配（输入框初值同路径但无标签前缀，不误配）。
    expect(
      find.textContaining('当前有效路径：${activeFile.path}'),
      findsOneWidget,
    );
    expect(find.text('已回退到默认位置'), findsOneWidget);
  });

  testWidgets('directory input is seeded from the store, not the file path', (
    tester,
  ) async {
    // Arrange — store 预置配置目录（≠ 解析后的有效文件路径）。
    ErrorFeedbackSettings.I.setLogDirectory(root.path);
    await tester.pumpWidget(buildSubject());

    // Assert — 输入框初值 = 配置目录本身（WR-02：以 error.log 文件路径作
    // 种子会让增量编辑把文件段带进目录值）；有效文件路径仍由常显行承载。
    expect(find.text(root.path), findsOneWidget);
    expect(
      find.textContaining('当前有效路径：${activeFile.path}'),
      findsOneWidget,
    );
  });
}
