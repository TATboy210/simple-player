import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';

import '../../helpers/fake_window_service.dart';

void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init（App 组合根需要它）。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // ErrorCardHost 经 ErrorReporterImpl.I 单例订阅呈现状态；
    // 每个测试重建单例，保证 FIFO/isReady 不跨测试泄漏。
    await ErrorReporterImpl.resetForTesting();
    ErrorReporterImpl.init();
  });

  // 真实 App 组合根，走 windowInitError 降级文字态 home —— 避免构造
  // MediaKitEngine/media_kit Player（headless mdk.dll 预存失败基线）。
  // builder 挂载层（D-10）对两种 home 一视同仁，降级路径同时充当
  // Task 2 的 windowInitError 存活用例。
  Widget buildApp() => App(
    startupTimeline: StartupTimeline(),
    windowService: FakeWindowService(),
    windowInitError: 'window init failed',
  );

  // 挂载层语义副本：直接复用 app.dart 的 buildErrorCardMount，
  // home 可注入自定义控件（穿透/故障注入用例需要）。
  Widget buildMountHarness({required Widget home}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
    builder: buildErrorCardMount,
  );

  group('ErrorCardHost 端到端呈现（tracer）', () {
    testWidgets('accepts a report and shows the card at the top-left', (
      tester,
    ) async {
      // Arrange：挂载宿主并等首帧 post-frame flushPresentation（D-12 门）。
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Act：空闲相位接纳一份真实报告。
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('引擎打开失败'),
        StackTrace.current,
      );
      await tester.pump();

      // Assert：卡片可见、显示报告 message 与「1 错误」计数徽标（D-01）。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('引擎打开失败'), findsOneWidget);
      expect(find.text('1 错误'), findsOneWidget);

      // D-10/CARD-06：卡片挂载在 app root 左上角。
      final topLeft = tester.getTopLeft(find.byType(ErrorCard));
      expect(topLeft.dx, lessThan(100));
      expect(topLeft.dy, lessThan(100));
    });

    testWidgets('presents a pre-mount report after the first flush (D-12)', (
      tester,
    ) async {
      // Arrange：模拟 bootstrap 窗口 —— 挂载前报告已入队且呈现未就绪。
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('bootstrap 窗口错误'),
        StackTrace.current,
      );
      expect(ErrorReporterImpl.I.presentation.value.isReady, isFalse);

      // Act：宿主 mount 后首帧 flushPresentation 补呈现；
      // post-frame 相位内到达的发布再推迟一帧落地。
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump();

      // Assert：预入队错误最终可见。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('bootstrap 窗口错误'), findsOneWidget);
    });

    testWidgets('taps outside the card bounds reach widgets below', (
      tester,
    ) async {
      // Arrange：卡片可见 + 卡片矩形之外放一个可点击探针（基础穿透，
      // 完整 hit-test 套件在 03-02）。
      var tapped = false;
      await tester.pumpWidget(
        buildMountHarness(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                key: const ValueKey('probe'),
                onTap: () => tapped = true,
                child: Container(width: 200, height: 100, color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('穿透检查'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：点击屏幕中央探针（卡片位于左上角，二者不相交）。
      await tester.tap(find.byKey(const ValueKey('probe')));
      await tester.pump();

      // Assert：控件回调触发 —— 内在尺寸挂载未吞掉点击。
      expect(tapped, isTrue);
    });

    testWidgets('stays visible above an opaque fullscreen-style route', (
      tester,
    ) async {
      // Arrange：报告已呈现。
      await tester.pumpWidget(buildApp());
      await tester.pump();
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('route 之下错误'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：push 一个不透明全屏样式 route（模拟 media_kit 全屏 route 层级）。
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('opaque'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert：D-10 —— 卡片在 route 之上仍可见。
      expect(find.text('opaque'), findsOneWidget);
      expect(find.byType(ErrorCard), findsOneWidget);
    });
  });

  group('CARD-05 build 期安全与宿主调度时序', () {
    testWidgets(
      'build-phase report arrival causes no secondary markNeedsBuild',
      (tester) async {
        // Arrange：模拟生产 FlutterError.onError 钩子 —— build 抛错进 reporter。
        // 关键：必须把错误继续交给 binding 的原 handler 记账（_pendingExceptionDetails），
        // 否则 flutter_test 会因异常记账断裂而挂起/断言失败。
        final errorTexts = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errorTexts.add(details.exception.toString());
          ErrorReporterImpl.I.reportFlutterSafely(details);
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        // Act：宿主已挂载的树中，一个子 widget build 抛出。
        await tester.pumpWidget(
          buildMountHarness(home: const Scaffold(body: _ThrowingBuildWidget())),
        );
        // 主动消费 binding 记账的预期异常（这是我们注入的故障，非回归）。
        final pending = tester.takeException();
        expect(pending?.toString(), contains('构建期炸弹'));
        // 帧尾应用推迟一帧落地，再一帧渲染 —— 两次 pump。
        await tester.pump();
        await tester.pump();

        // Assert：原错误卡片在 post-frame 后出现。
        expect(find.byType(ErrorCard), findsOneWidget);
        expect(find.textContaining('构建期炸弹'), findsOneWidget);
        // 原错误确实经钩子到达。
        expect(errorTexts.where((t) => t.contains('构建期炸弹')), isNotEmpty);
        // CARD-05：无 "setState() or markNeedsBuild() called during build"
        // 次生断言 —— 相位守卫把 build 期同步发布封死在适配层。
        expect(errorTexts.where((t) => t.contains('markNeedsBuild')), isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets('same-frame reports converge to one end-of-frame update', (
      tester,
    ) async {
      // Arrange：统计 BuildOwner 的 onBuildScheduled 次数 —— setState 本身
      // 调度 1 帧；帧尾适配器应用终值再调度 1 帧。若实现是「逐份应用」则
      // 会出现第 3 次（甚至逐份抖动的多次）调度。
      final owner = tester.binding.buildOwner!;
      final originalOnBuildScheduled = owner.onBuildScheduled;
      var buildScheduledCount = 0;
      owner.onBuildScheduled = () {
        buildScheduledCount++;
        final original = originalOnBuildScheduled;
        if (original != null) original();
      };
      addTearDown(() => owner.onBuildScheduled = originalOnBuildScheduled);

      final phases = <SchedulerPhase>[];
      await tester.pumpWidget(
        buildMountHarness(
          home: Scaffold(body: _ReportInBuildHarness(phases: phases)),
        ),
      );
      // 宿主就绪：首帧 flushPresentation 与补呈现均已完成。
      await tester.pump();
      await tester.pump();

      // Act：触发一次在 persistentCallbacks 相位内接纳两份不同报告的 build。
      buildScheduledCount = 0;
      tester
          .state<_ReportInBuildHarnessState>(find.byType(_ReportInBuildHarness))
          .reportDuringBuild();
      await tester.pump(); // 报告在 build 期入队;帧尾合并应用
      await tester.pump(); // 渲染合并结果

      // Assert：报告到达时确实处于 persistentCallbacks 相位 ——
      // 适配值推迟到帧尾才变化（无 build 期同步 setState）。
      expect(phases, everyElement(SchedulerPhase.persistentCallbacks));
      // 收敛为一次终值更新：setState 帧 + 帧尾一次应用 = 2 次调度。
      expect(buildScheduledCount, 2);
      // 卡片显示队首（甲）而非后入队的乙，徽标计总数。
      expect(find.textContaining('同帧报告甲'), findsOneWidget);
      expect(find.textContaining('同帧报告乙'), findsNothing);
      expect(find.text('2 错误'), findsOneWidget);
    });
  });
}

/// build 期抛错的探针 widget —— 故障注入点（FlutterError.onError 触发
/// reportFlutterSafely,模拟 main.dart 生产钩子）。
class _ThrowingBuildWidget extends StatelessWidget {
  const _ThrowingBuildWidget();

  @override
  Widget build(BuildContext context) => throw StateError('构建期炸弹');
}

/// 在自身 build（persistentCallbacks 相位）内接纳两份不同报告的探针，
/// 用于验证宿主相位守卫的同帧合并语义。
class _ReportInBuildHarness extends StatefulWidget {
  const _ReportInBuildHarness({required this.phases});

  final List<SchedulerPhase> phases;

  @override
  State<_ReportInBuildHarness> createState() => _ReportInBuildHarnessState();
}

class _ReportInBuildHarnessState extends State<_ReportInBuildHarness> {
  bool _reported = false;

  /// 测试入口：下一次 build 在 build 相位内接纳报告。
  void reportDuringBuild() {
    setState(() => _reported = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_reported) {
      // 记录报告到达时的调度相位,证明这是真正的 build 期发布。
      widget.phases.add(SchedulerBinding.instance.schedulerPhase);
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('同帧报告甲'),
        StackTrace.current,
      );
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('同帧报告乙'),
        StackTrace.current,
      );
    }
    return const SizedBox.shrink();
  }
}
