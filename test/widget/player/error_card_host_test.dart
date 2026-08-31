import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

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
    // D-11 快照 effect：徽标轮览数据源须与生产 main.dart 同一接线
    // （reporter 既有 effects 缝 → ErrorCaptureSnapshot.I.record）。
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
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

  // ---------- CR-01 生产挂载约束：展开卡片不再无界 ----------
  //
  // 关键：必须复用 buildErrorCardMount（生产挂载路径）——旧套件全部把卡片
  // 挂在有界 Align/Center 里，掩盖了 RenderStack 对 left/top Positioned
  // 子节点给无界约束的问题。本组用无界 Positioned + 长调用栈复现原始缺陷。
  group('CR-01 挂载约束（生产 mount 路径）', () {
    testWidgets(
      'expanded card is width/height bounded and taps outside pass through',
      (tester) async {
        // Arrange：卡片下方铺满点击探针；真实 intake 接纳长调用栈报告。
        var probeTaps = 0;
        await tester.pumpWidget(
          buildMountHarness(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('probe'),
                      onTap: () => probeTaps++,
                      child: Container(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        // 长调用栈：每行远超展开宽度上界，无界挂载下曾把卡片撑到 ~1133px 宽
        // （review CR-01 实测值），并使滚动与穿透全部失效。
        final longStack = List.generate(
          30,
          (i) =>
              '#$i      frame_$i '
              '(package:simple_player_flutter/lib/kernel/engine/'
              'media_kit_engine.dart:${100 + i}:7)',
        ).join('\n');
        ErrorReporterImpl.I.reportBootstrapSafely(
          StateError('约束检查'),
          StackTrace.fromString(longStack),
        );
        await tester.pump();
        expect(find.byType(ErrorCard), findsOneWidget);

        // Act：整卡点击展开。
        await tester.tapAt(tester.getCenter(find.text('Bad state: 约束检查')));
        await tester.pump();
        expect(find.text('调用栈'), findsOneWidget);

        // Assert：宽度 ≤ token 上界（无界挂载回归锁）。
        final cardRect = tester.getRect(find.byType(ErrorCard));
        expect(
          cardRect.width,
          lessThanOrEqualTo(Tokens.errorCardExpandedMaxWidth),
        );
        // Assert：高度不溢出窗口 —— bounded maxHeight 让展开详情区进入
        // Flexible+SingleChildScrollView 滚动路径而非溢出窗口底部。
        final windowHeight = MediaQuery.sizeOf(
          tester.element(find.byType(ErrorCard)),
        ).height;
        expect(cardRect.bottom, lessThanOrEqualTo(windowHeight));

        // Act / Assert：展开态下卡片矩形之外点击仍穿透到下层控件（ClipRRect
        // 命中裁剪以卡片真实矩形为准 —— 有界卡片不再吞掉全窗口点击）。
        await tester.tapAt(const Offset(700, 300));
        await tester.pump();
        expect(probeTaps, 1);
        expect(find.text('调用栈'), findsOneWidget);
      },
    );
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
      // D-01 替换语义（03-03）：卡片显示**最新**入队的乙，甲留在快照中
      // 经徽标轮览可回看 —— 适配值保持 reporter 队首语义，渲染层取快照。
      expect(find.textContaining('同帧报告乙'), findsOneWidget);
      expect(find.textContaining('同帧报告甲'), findsNothing);
      expect(find.text('2 错误'), findsOneWidget);
    });
  });

  // ---------- 03-03 Task 2：严重级路由（D-02）与徽标轮览（D-01/D-11） ----------
  //
  // warning 路由的合成数据说明：四个捕获源均硬编码 error/fatal（D-02 分层
  // 本就是给 Phase 4/5 来源的前瞻），`ErrorReporterImpl.forTesting` intake
  // 产不出 warning —— 直接向公开的 `presentation` ValueNotifier 发布合成
  // 快照（宿主唯一监听缝，零 kernel 改动）。error/fatal 用例仍走真实 intake。
  //
  // 合成报告构造器：不可变快照直构（同 03-02 口径：纯数据，零引擎构造）。
  ErrorReport syntheticReport({
    required String message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? eventId,
  }) {
    final timestamp = DateTime.utc(2026, 8, 31, 8, 0, 0);
    return ErrorReport(
      eventId: eventId ?? 'synthetic-$message',
      source: ErrorSource.playerEngine,
      severity: severity,
      firstOccurredAt: timestamp,
      lastOccurredAt: timestamp,
      errorType: 'SyntheticError',
      playerErrorCode: null,
      message: message,
      rawStackTrace: '#0 synthetic (synthetic.dart:1:1)',
      mediaPath: null,
      occurrenceCount: 1,
    );
  }

  // 直接向 reporter.presentation 发布快照（宿主适配层唯一监听缝）。
  void publishPresentation(ErrorReport? report, {int pendingCount = 0}) {
    ErrorReporterImpl.I.presentation.value = ErrorPresentationState(
      current: report,
      pendingCount: pendingCount,
      isReady: true,
    );
  }

  group('warning 严重级路由（D-02）', () {
    testWidgets('warning head routes to OSD and advances exactly once', (
      tester,
    ) async {
      // Arrange：宿主就绪 + presentation/OSD 通知计数（恰好一次断言缝）。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      var presentationChanges = 0;
      void onPresentationChanged() => presentationChanges++;
      ErrorReporterImpl.I.presentation.addListener(onPresentationChanged);
      addTearDown(
        () => ErrorReporterImpl.I.presentation.removeListener(
          onPresentationChanged,
        ),
      );
      var osdShows = 0;
      void onOsdMessage() {
        if (OsdService.I.message.value != null) osdShows++;
      }

      OsdService.I.message.addListener(onOsdMessage);
      addTearDown(() => OsdService.I.message.removeListener(onOsdMessage));

      // Act：warning 成为队首（合成快照直接发布）。
      final warning = syntheticReport(
        message: '降级警告',
        severity: ErrorSeverity.warning,
        eventId: 'warn-1',
      );
      publishPresentation(warning);
      await tester.pump();

      // Assert：OSD 收到提示（warning 图标）、卡片不显示该 warning。
      expect(osdShows, 1);
      expect(OsdService.I.message.value?.text, '降级警告');
      expect(OsdService.I.message.value?.icon, Icons.warning_amber_outlined);
      expect(find.byType(ErrorCard), findsNothing);

      // Assert：队列恰好推进一次 —— 发布(1) + dismissCurrent 推进(2)。
      expect(presentationChanges, 2);

      // Act：重复触发（同 eventId 新快照实例 —— 模拟去重合并后的重发布 /
      // 相位守卫双回调以同一终值调用 _apply 的场景）。
      publishPresentation(warning);
      await tester.pump();

      // Assert：无二次提示、无二次 dismiss（无重建循环，T-03-09）。
      expect(osdShows, 1);
      expect(presentationChanges, 3); // 重复发布本身 +1，守卫后无推进

      // Act / Assert：warning 分流后下一 error 正常上卡。
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('后续错误'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('后续错误'), findsOneWidget);

      // 推进 OSD hold 计时器（osdDefaultHoldMs=1200），避免测试结束遗留
      // pending timer；hide() 置空 message，不影响上面的非空计数断言。
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('badge 徽标轮览（D-01/D-11）', () {
    testWidgets(
      'newest error replaces the card and badge counts the snapshot',
      (tester) async {
        // Arrange。
        await tester.pumpWidget(
          buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
        );
        await tester.pump();

        // Act：连续接纳 3 份不同报告（真实 intake）。
        for (final message in ['错误一', '错误二', '错误三']) {
          ErrorReporterImpl.I.reportBootstrapSafely(
            StateError(message),
            StackTrace.current,
          );
        }
        await tester.pump();

        // Assert：D-01 替换语义 —— 卡片显示最新，不堆叠；徽标 = 快照长度。
        expect(find.byType(ErrorCard), findsOneWidget);
        expect(find.textContaining('错误三'), findsOneWidget);
        expect(find.textContaining('错误一'), findsNothing);
        expect(find.text('3 错误'), findsOneWidget);

        // Act / Assert：新报告到达替换内容，计数跟进。
        ErrorReporterImpl.I.reportBootstrapSafely(
          StateError('错误四'),
          StackTrace.current,
        );
        await tester.pump();
        expect(find.textContaining('错误四'), findsOneWidget);
        expect(find.text('4 错误'), findsOneWidget);
      },
    );

    testWidgets('badge tap cycles older through the snapshot and wraps', (
      tester,
    ) async {
      // Arrange：3 份报告在卡，显示最新。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      for (final message in ['错误一', '错误二', '错误三']) {
        ErrorReporterImpl.I.reportBootstrapSafely(
          StateError(message),
          StackTrace.current,
        );
      }
      await tester.pump();
      expect(find.textContaining('错误三'), findsOneWidget);

      // dismissCurrent 零调用观察缝：轮览期间 presentation 通知数不增。
      var presentationChanges = 0;
      void onPresentationChanged() => presentationChanges++;
      ErrorReporterImpl.I.presentation.addListener(onPresentationChanged);
      addTearDown(
        () => ErrorReporterImpl.I.presentation.removeListener(
          onPresentationChanged,
        ),
      );

      // Act / Assert：点击徽标沿快照向旧轮览（循环）。
      await tester.tap(find.byKey(const ValueKey('error-card-badge')));
      await tester.pump();
      expect(find.textContaining('错误二'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('error-card-badge')));
      await tester.pump();
      expect(find.textContaining('错误一'), findsOneWidget);
      // 轮览到最旧后再点 → 回到最新（循环语义）。
      await tester.tap(find.byKey(const ValueKey('error-card-badge')));
      await tester.pump();
      expect(find.textContaining('错误三'), findsOneWidget);

      // Assert：轮览是纯视图偏移 —— presentation 通知数保持 0。
      expect(presentationChanges, 0);
    });

    testWidgets('snapshot caps at the bound and evicts the oldest', (
      tester,
    ) async {
      // Arrange：连续 21 份报告，快照上界 20（命名常量 _maxSnapshotLength）。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();

      // Act：21 份不同报告。
      for (var i = 1; i <= 21; i++) {
        ErrorReporterImpl.I.reportBootstrapSafely(
          StateError('溢出-$i'),
          StackTrace.current,
        );
      }
      await tester.pump();

      // Assert：徽标封顶于上界；最旧被挤出（轮览到最旧应显示第 2 份）。
      expect(find.text('20 错误'), findsOneWidget);
      for (var tap = 0; tap < 19; tap++) {
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
      }
      expect(find.textContaining('溢出-2'), findsOneWidget);
      expect(find.textContaining('溢出-1'), findsNothing);
    });

    testWidgets(
      'manual close during cycling advances the real head and resets',
      (tester) async {
        // Arrange：3 份报告在卡（显示最新），轮览到最旧。
        await tester.pumpWidget(
          buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
        );
        await tester.pump();
        for (final message in ['错误一', '错误二', '错误三']) {
          ErrorReporterImpl.I.reportBootstrapSafely(
            StateError(message),
            StackTrace.current,
          );
        }
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
        expect(find.textContaining('错误一'), findsOneWidget);

        // Act：轮览状态下手动关闭 —— dismissCurrent 推进真实队首并重置轮览。
        await tester.tap(find.byKey(const ValueKey('error-card-close')));
        await tester.pump();

        // Assert：真实队首（一）被消费；快照移除后计数减一；轮览重置到最新。
        expect(find.textContaining('错误三'), findsOneWidget);
        expect(find.text('2 错误'), findsOneWidget);

        // 轮览重置后可继续向旧翻页：此处只验证翻一页命中二。
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
        expect(find.textContaining('错误二'), findsOneWidget);
      },
    );

    testWidgets(
      'new report arrival resets the cycle offset (D-01 replacement)',
      (tester) async {
        // Arrange：3 份报告在卡，轮览到最旧（错误一）。
        await tester.pumpWidget(
          buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
        );
        await tester.pump();
        for (final message in ['错误一', '错误二', '错误三']) {
          ErrorReporterImpl.I.reportBootstrapSafely(
            StateError(message),
            StackTrace.current,
          );
        }
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('error-card-badge')));
        await tester.pump();
        expect(find.textContaining('错误一'), findsOneWidget);

        // Act：轮览中新报告（错误四）到达 —— 快照变化必须重置轮览偏移（CR-02），
        // 否则偏移取模后显示位移后的陈旧条目，D-01 替换语义被劫持。
        ErrorReporterImpl.I.reportBootstrapSafely(
          StateError('错误四'),
          StackTrace.current,
        );
        await tester.pump();

        // Assert：卡片显示新报告，徽标计数跟进。
        expect(find.textContaining('错误四'), findsOneWidget);
        expect(find.textContaining('错误一'), findsNothing);
        expect(find.text('4 错误'), findsOneWidget);
      },
    );
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
