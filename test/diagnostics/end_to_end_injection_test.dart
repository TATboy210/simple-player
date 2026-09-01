/// 端到端整合注入用例(VER-01, D-01)——四源各经真实注入入口走完整链路。
///
/// End-to-end injection suite (VER-01, D-01): each of the four capture
/// sources is injected once through its real entry point and must produce
/// the full three-piece evidence set — exactly one new reporter report,
/// one new diagnostic-file record, and a visible ErrorCard summary.
///
/// 四源入口先例:
/// 源1 FlutterError.onError → GlobalErrorHooks 框架回调
///     (先例 global_error_hooks_test 'presents framework details before
///     forwarding them to the reporter')。
/// 源2 PlatformDispatcher.onError → GlobalErrorHooks dispatcher 回调
///     (先例 'forwards exact dispatcher error and stack then returns true')。
/// 源3 runZonedGuarded 启动兜底 → BootstrapErrorFallback.report
///     (main.dart:119 生产 zone handler 同一函数)。
/// 源4 PlayerError → PlayerErrorReportBridge + FakeEngine.lastError
///     (先例 player_error_report_bridge_test)。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/global_error_hooks.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/player_error_report_bridge.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/main.dart' show BootstrapErrorFallback;
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';

import '../helpers/fake_engine.dart';

void main() {
  setUpAll(() {
    // 诊断单例测试惯例:KernelLogger 先复位再 init(error_card_host_test 同款)。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  // 每用例独立的临时诊断文件 + 重建 reporter 单例,保证 FIFO/文件不跨测试泄漏。
  late File target;
  late DelegatingDiagnosticLogEffect delegate;
  late ErrorLogFileSink sink;

  setUp(() async {
    // Arrange:temp 目录 FileSink(先例 error_log_file_sink_test / hooks 测试)。
    final dir = await Directory.systemTemp.createTemp('e2e_injection');
    target = File('${dir.path}${Platform.pathSeparator}error.log');
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    delegate = DelegatingDiagnosticLogEffect();
    // 与生产 main.dart 同一接线:委托 effect + 快照 effect + 状态源单一。
    ErrorReporterImpl.init(
      effects: [delegate.record, ErrorCaptureSnapshot.I.record],
      diagnosticLogStatus: delegate,
    );
    sink = ErrorLogFileSink(file: target);
    delegate.activate(sink: sink, resolvedPath: target.path);
    // teardown 捕获 setUp 时刻的目录值(禁引用共享 late 变量 —— 异步
    // delete 若跨测试迟执行,会误删下一用例的新目录,曾致 PathNotFound)。
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // 清理失败不致命(临时目录由 OS 兜底回收)。
      }
    });
    addTearDown(() {
      // 04-04 真实 I/O 协议:teardown 禁 await plain async fn →
      // dispose 走 fire-and-forget(文件断言已在用例体内锚定落点)。
      unawaited(delegate.dispose());
    });
  });

  /// 挂载生产 ErrorCardHost(复用 app.dart 挂载层 builder,host 套件同款)。
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox.shrink()),
        builder: buildErrorCardMount,
      ),
    );
    await tester.pump();
  }

  /// 断言三件套之一:reporter 恰新增一份该源报告(消息互异避开去重窗)。
  void expectSingleReport(String message) {
    final reports = ErrorReporterImpl.I.queuedReports;
    expect(reports, hasLength(1));
    expect(reports.single.message, contains(message));
    expect(reports.single.occurrenceCount, 1); // 新报告而非去重合并
  }

  /// 断言三件套之二:诊断文件新增该源记录(锚定真实文件落点)。
  ///
  /// 04-04 真实 I/O 协议:FileSink 写链续体在 FakeAsync zone 创建 ——
  /// 禁裸 await drain(会饿死)。改为交替 runAsync(让真实事件循环
  /// 派发 OS 写完成)+ pump(刷新 fake 微任务推进链)轮询;读失败
  /// (文件未落盘/目录被迟到的跨测试 delete 清理)按未就绪处理而非抛异常。
  Future<void> expectFileRecord(WidgetTester tester, String message) async {
    String? readQuietly() {
      try {
        return target.readAsStringSync();
      } on PathNotFoundException {
        return null;
      } on FileSystemException {
        return null;
      }
    }

    var contents = '';
    for (
      var attempt = 0;
      attempt < 60 && !contents.contains(message);
      attempt += 1
    ) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      contents = readQuietly() ?? '';
    }
    expect(contents, contains(message));
  }

  /// 断言三件套之三:ErrorCard 呈现且该源摘要可见、计数徽标为 1。
  ///
  /// [displayed] 覆盖卡片实际渲染文本:PlayerError 报告经 l10nKey 解析
  /// (error_card.dart _resolveMessage),卡片显示本地化文案而非原始消息。
  void expectCardVisible(String message, {String? displayed}) {
    expect(find.byType(ErrorCard), findsOneWidget);
    expect(find.textContaining(displayed ?? message), findsOneWidget);
    expect(find.text('1 错误'), findsOneWidget);
  }

  group('四源端到端整合注入(VER-01, D-01)', () {
    testWidgets(
      'framework error via the installed FlutterError.onError hook yields '
      'report, file record, and card',
      (tester) async {
        // Arrange:经 GlobalErrorHooks 安装缝捕获真实框架回调,
        // 不污染进程全局 handler(先例 hooks 测试 forTesting 组装)。
        FlutterExceptionHandler? frameworkCallback;
        final hooks = GlobalErrorHooks.forTesting(
          setFrameworkErrorHandler: (callback) => frameworkCallback = callback,
          setPlatformErrorHandler: (_) {},
          presentFrameworkError: (_) {},
        );
        hooks.installCallbacks(ErrorReporterImpl.I);
        await pumpHost(tester);

        // Act:框架回调注入一次 FlutterError。
        frameworkCallback?.call(
          FlutterErrorDetails(
            exception: StateError('框架源错误'),
            stack: StackTrace.current,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Assert:三件套(报告 / 文件 / 卡片)。
        expectSingleReport('框架源错误');
        await expectFileRecord(tester, '框架源错误');
        expectCardVisible('框架源错误');
      },
    );

    testWidgets(
      'uncaught async error via the PlatformDispatcher.onError hook yields '
      'report, file record, and card',
      (tester) async {
        // Arrange:捕获 dispatcher 缝回调(先例 'forwards exact dispatcher
        // error and stack then returns true')。
        PlatformErrorCallback? dispatcherCallback;
        final hooks = GlobalErrorHooks.forTesting(
          setFrameworkErrorHandler: (_) {},
          setPlatformErrorHandler: (callback) => dispatcherCallback = callback,
          presentFrameworkError: (_) {},
        );
        hooks.installCallbacks(ErrorReporterImpl.I);
        await pumpHost(tester);

        // Act:dispatcher 回调注入一次未捕获异步错误,返回 true(已处置)。
        final handled = dispatcherCallback?.call(
          StateError('异步源错误'),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        // Assert:三件套 + dispatcher 回调返回 true。
        expect(handled, isTrue);
        expectSingleReport('异步源错误');
        await expectFileRecord(tester, '异步源错误');
        expectCardVisible('异步源错误');
      },
    );

    testWidgets(
      'guarded-zone error via the production BootstrapErrorFallback.report '
      'yields report, file record, and card',
      (tester) async {
        // Arrange:宿主就绪(reporter 已 init,fallback 走初始化分支)。
        await pumpHost(tester);

        // Act:main.dart runZonedGuarded 兜底入口(生产 zone handler 同一
        // 静态函数)注入一次 bootstrap 错误。
        BootstrapErrorFallback.report(
          StateError('bootstrap 源错误'),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        // Assert:三件套。
        expectSingleReport('bootstrap 源错误');
        await expectFileRecord(tester, 'bootstrap 源错误');
        expectCardVisible('bootstrap 源错误');
      },
    );

    testWidgets(
      'PlayerError forwarded by the bridge yields report, file record, '
      'and card',
      (tester) async {
        // Arrange:桥接真实链路(engine.lastError 通知 → bridge →
        // reporter intake,先例 player_error_report_bridge_test)。
        final engine = FakeEngine();
        final bridge = PlayerErrorReportBridge(
          engine: engine,
          reporter: ErrorReporterImpl.I,
          currentMediaPath: () => 'e2e.mp4',
        );
        addTearDown(() {
          bridge.dispose();
          engine.dispose();
        });
        await pumpHost(tester);

        // Act:FileError 经桥注入一次。
        engine.lastError.value = FileError(
          FileErrorCode.pathEmpty,
          '播放器源错误',
        );
        await tester.pump();
        await tester.pump();

        // Assert:三件套。卡片摘要按 D-02 l10n 契约显示解析文案
        // (pathEmpty → errorFilePathEmpty),原始消息用于报告与文件证据。
        expectSingleReport('播放器源错误');
        await expectFileRecord(tester, '播放器源错误');
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ErrorCard)),
        );
        expectCardVisible('播放器源错误', displayed: l10n.errorFilePathEmpty);
      },
    );
  });
}
