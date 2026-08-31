/// MIG-01 卡片路径集成测试 —— 旧横幅（legacy banner）删除后的唯一展示路径证据。
///
/// **等效证明已发生在删除前**（见 03-04 Task 1 提交 372b10a9：双路径对同一组
/// 代表性 PlayerError case 的消息 + 严重级断言全绿），本文件此后保留为
/// 卡片路径（bridge → reporter → ErrorCardHost）的集成证据。
///
/// **等效定义（D-09）**：同一引擎错误在两条展示路径上给出相同的可见反馈 ——
/// ① 相同的 l10n 解析消息；② 可辨认的严重级语义（fatal/error 一致）。
/// 断言集**不含** reopen/select-other-file/retry 动作按钮查找 —— 动作按钮按
/// 用户决策（D-09）不迁移到新卡片；也不含 fullMediaPath 可见性断言（T-03-05）。
///
/// **路径差异（非等效破坏项）**：同一错误重复发生时，桥接路径的
/// occurrenceCount 去重合并语义在新卡片展开区可见（旧横幅无此能力）——
/// 单独用例记录该增量能力，不参与 D-09 等效判定。
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

  // ── 卡片路径 harness：MaterialApp builder 挂 ErrorCardHost（03-01 挂载形态，
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

  group('MIG-01 卡片路径集成证据（删除前已双路径等效，D-07/D-09）', () {
    // 代表性 case 集：四类 PlayerError 子类型 + isFatal 案例。
    // expectedMessage = l10n 解析结果（en ARB，与删除前的旧横幅逐项一致）；
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
        '${scenario.label}: card shows the l10n message and severity color',
        (tester) async {
          // ── 卡片路径：FakeEngine → 真实桥 → reporter → 宿主 → 卡片 ──
          final fixture = _BridgeFixture();
          addTearDown(fixture.dispose);
          await tester.pumpWidget(buildCardHarness());
          await tester.pump(); // 首帧 post-frame flushPresentation（D-12 门）
          fixture.engine.state.value = MediaState.error;
          fixture.engine.lastError.value = scenario.errorFactory();
          await tester.pump();

          // 等效断言 ①：l10n 解析消息可见（D-09：零动作按钮查找）。
          expect(find.byType(ErrorCard), findsOneWidget);
          expect(find.text(scenario.expectedMessage), findsOneWidget);
          // 等效断言 ②：severity 色点 + 卡片 border 同色 ——
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
        // 旧横幅（legacy banner）无重复计数能力 —— 该差异按计划记录于文件头
        // 注释，不参与等效判定。
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
