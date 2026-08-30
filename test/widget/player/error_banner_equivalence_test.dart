/// MIG-01 等效覆盖测试 —— 旧横幅删除前的双路径判定集（D-07 判定 + D-09 断言边界）。
///
/// **等效定义（D-09）**：同一引擎错误在两条展示路径上给出相同的可见反馈 ——
/// ① 相同的 l10n 解析消息；② 可辨认的严重级语义（fatal/error 一致）。
/// 断言集**不含** reopen/select-other-file/retry 动作按钮查找 —— 动作按钮按
/// 用户决策（D-09）不迁移到新卡片；也不含 fullMediaPath 可见性断言（T-03-05）。
///
/// **双路径**：
/// - 旧路径（legacy banner）：FakeEngine 直连旧横幅 widget（同 error_banner
///   测试的 buildSubject 形态，`state == MediaState.error` 门控）；
/// - 新路径：FakeEngine 经真实 PlayerErrorReportBridge → ErrorReporterImpl.I
///   （player_services.dart:148 同构的生产接线）→ ErrorCardHost → ErrorCard。
///
/// **路径差异（非等效破坏项）**：同一错误重复发生时，桥接路径的
/// occurrenceCount 去重合并语义在新卡片展开区可见（旧横幅无此能力）——
/// 单独用例记录该增量能力，不参与 D-09 等效判定。
///
/// 本文件在删除（03-04 Task 3）前对**双路径同时**运行（删除安全前提）；
/// 删除后移除旧 harness，保留为卡片路径集成证据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/player_error_report_bridge.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_banner.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';

void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // 每个测试重建 reporter 单例 + 呈现快照，保证 FIFO/isReady 不跨测试泄漏；
    // D-11 快照 effect 与生产 main.dart 同一接线。
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
  });

  // ── 旧路径 harness：FakeEngine 直连旧横幅（error_banner_test 同形态）──
  Widget buildLegacyHarness(FakeEngine engine) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ErrorBanner(engine: engine)),
  );

  // ── 新路径 harness：MaterialApp builder 挂 ErrorCardHost（03-01 挂载形态，
  //    复用 app.dart 的 buildErrorCardMount 与生产同一挂载语义）──
  Widget buildCardHarness() => const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox.shrink()),
    builder: buildErrorCardMount,
  );

  // D-03 severity 语义色映射 —— 与 error_card.dart 的 _severityColor 同源。
  Color severityColor(ErrorSeverity severity) => switch (severity) {
    ErrorSeverity.warning => Tokens.warning,
    ErrorSeverity.error => Tokens.danger,
    ErrorSeverity.fatal => Tokens.dangerFatal,
  };

  // 新卡片 severity 色点 finder（error_card_test.dart 同款谓词：circle 装饰）。
  Finder severityDot(ErrorSeverity severity) =>
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == severityColor(severity);
      });

  // 旧横幅 danger 底色探针（severity 观感：与旧横幅装饰同值）—— 旧路径
  // 不区分 fatal/error，danger 底色 + error_outline 图标即其全部严重级语义。
  bool legacySurfaceVisible(WidgetTester tester) =>
      tester.widgetList<Container>(find.byType(Container)).any((widget) {
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == Tokens.danger.withValues(alpha: 0.78) &&
            decoration.borderRadius == BorderRadius.circular(8);
      });

  group('MIG-01 双路径等效判定（D-07，删除前硬门）', () {
    // 代表性 case 集：四类 PlayerError 子类型 + isFatal 案例。
    // expectedMessage = 两条路径共用的 l10n 解析结果（en ARB）；
    // expectedSeverity = ErrorReporterImpl 对 isFatal 的映射（fatal/error）。
    final scenarios = <_EquivalenceScenario>[
      _EquivalenceScenario(
        label: 'fileNotFound (file)',
        errorFactory: () =>
            FileError(FileErrorCode.fileNotFound, 'raw message ignored'),
        expectedMessage: 'File not found',
        expectedSeverity: ErrorSeverity.error,
      ),
      _EquivalenceScenario(
        label: 'unsupportedFormat (codec)',
        errorFactory: () =>
            CodecError(CodecErrorCode.unsupportedFormat, 'raw message ignored'),
        expectedMessage: 'Unsupported media format',
        expectedSeverity: ErrorSeverity.error,
      ),
      _EquivalenceScenario(
        label: 'playFailed (playback)',
        errorFactory: () =>
            PlaybackError(PlaybackErrorCode.playFailed, 'raw message ignored'),
        expectedMessage: 'Playback failed',
        expectedSeverity: ErrorSeverity.error,
      ),
      _EquivalenceScenario(
        label: 'unknown (unclassified)',
        errorFactory: () => UnknownError('raw message ignored'),
        expectedMessage: 'An unexpected error occurred',
        expectedSeverity: ErrorSeverity.error,
      ),
      _EquivalenceScenario(
        label: 'pathTraversal (isFatal)',
        errorFactory: () =>
            FileError(FileErrorCode.pathTraversal, 'raw message ignored'),
        expectedMessage: 'Invalid file path',
        expectedSeverity: ErrorSeverity.fatal,
      ),
    ];

    for (final scenario in scenarios) {
      testWidgets(
        '${scenario.label}: both paths show the same message and severity',
        (tester) async {
          // ── 旧路径：FakeEngine 直连旧横幅 ──
          final legacyEngine = FakeEngine();
          addTearDown(legacyEngine.dispose);
          // 旧横幅 state==error 门控：先置状态再注入错误（simulateError 同序）。
          legacyEngine.state.value = MediaState.error;
          legacyEngine.lastError.value = scenario.errorFactory();
          await tester.pumpWidget(buildLegacyHarness(legacyEngine));

          // 等效断言 ①：l10n 解析消息可见（D-09：零动作按钮查找）。
          expect(find.text(scenario.expectedMessage), findsOneWidget);
          // 等效断言 ②（旧路径侧）：danger 底色 + error_outline 图标。
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(
            legacySurfaceVisible(tester),
            isTrue,
            reason: '旧横幅 danger 底色（error 级观感）必须可见',
          );

          // ── 新路径：FakeEngine → 真实桥 → reporter → 宿主 → 卡片 ──
          final fixture = _BridgeFixture();
          addTearDown(fixture.dispose);
          await tester.pumpWidget(buildCardHarness());
          await tester.pump(); // 首帧 post-frame flushPresentation（D-12 门）
          fixture.engine.state.value = MediaState.error;
          fixture.engine.lastError.value = scenario.errorFactory();
          await tester.pump();

          // 等效断言 ①：与旧路径相同的 l10n 解析消息。
          expect(find.byType(ErrorCard), findsOneWidget);
          expect(find.text(scenario.expectedMessage), findsOneWidget);
          // 等效断言 ②（新路径侧）：severity 色点 + 卡片 border 同色 ——
          // fatal 与 error 语义可分辨（D-03）。
          expect(
            severityDot(scenario.expectedSeverity),
            findsOneWidget,
            reason: '新卡片 severity 色点必须可见且与 isFatal 映射一致',
          );
          final glass = tester.widget<GlassContainer>(
            find.byType(GlassContainer),
          );
          expect(
            glass.border?.top.color,
            severityColor(scenario.expectedSeverity),
          );
        },
      );
    }
  });

  group('路径差异记录（非等效破坏项，D-09）', () {
    testWidgets(
      'repeat occurrence merges on the bridge path; count is visible on the expanded card',
      (tester) async {
        // 旧横幅无重复计数能力 —— 该差异按计划记录于文件头注释，不参与等效判定。
        final fixture = _BridgeFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(buildCardHarness());
        await tester.pump(); // 首帧 flushPresentation（D-12 门）

        // 同一错误两次独立发生（同 message 的两个实例 —— reporter 去重窗口内合并）。
        fixture.engine.state.value = MediaState.error;
        fixture.engine.lastError.value = PlaybackError(
          PlaybackErrorCode.playFailed,
          'repeated failure',
        );
        await tester.pump();
        fixture.engine.lastError.value = PlaybackError(
          PlaybackErrorCode.playFailed,
          'repeated failure',
        );
        await tester.pump();

        expect(find.byType(ErrorCard), findsOneWidget);
        // 展开卡片（整卡点击切换，D-04；点 message 区避开徽标/复制手势）。
        await tester.tapAt(tester.getCenter(find.text('Playback failed')));
        await tester.pump();
        // ⑤ 重复信息段可见：occurrenceCount == 2（en ARB 'Repeats: {count}'）。
        expect(find.text('Repeats: 2'), findsOneWidget);
      },
    );
  });
}

/// 生产桥接 fixture —— player_services.dart:148 同构：FakeEngine +
/// PlayerErrorReportBridge（reporter 用单例 ErrorReporterImpl.I）+
/// PlaybackController(onError: bridge.reportControllerError)。
final class _BridgeFixture {
  _BridgeFixture() : engine = FakeEngine() {
    bridge = PlayerErrorReportBridge(
      engine: engine,
      reporter: ErrorReporterImpl.I,
      currentMediaPath: () => controller.currentPath.value,
    );
    controller = PlaybackController(
      engine: engine,
      onError: bridge.reportControllerError,
    );
  }

  final FakeEngine engine;
  late final PlayerErrorReportBridge bridge;
  late final PlaybackController controller;

  /// 依赖顺序 dispose（bridge → controller → engine，同 service 容器释放序）。
  void dispose() {
    bridge.dispose();
    controller.dispose();
    engine.dispose();
  }
}

/// 等效判定 case —— 错误子类型工厂 + 期望可见反馈（消息 + severity）。
final class _EquivalenceScenario {
  const _EquivalenceScenario({
    required this.label,
    required this.errorFactory,
    required this.expectedMessage,
    required this.expectedSeverity,
  });

  final String label;
  final PlayerError Function() errorFactory;
  final String expectedMessage;
  final ErrorSeverity expectedSeverity;
}
