import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// ErrorCard 折叠/展开详情测试（CARD-03/D-03/D-04，T-03-05 脱敏边界）。
///
/// 数据策略：一律经 `ErrorReporterImpl.forTesting` 真实 intake 产出报告
/// （不构造 MediaKitEngine —— headless mdk.dll 预存基线）；location 用注入
/// enricher 固定，避免依赖测试环境真实源码读取。卡片为纯呈现 widget，
/// 单例只用于 diagnosticLogPath 读取。
void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // 卡片 build 内读取 ErrorReporterImpl.I.diagnosticLogPath；
    // 每个测试重建单例，保证 log 状态不跨测试泄漏。
    await ErrorReporterImpl.resetForTesting();
    ErrorReporterImpl.init();
  });

  // 卡片纯呈现测试 harness：直接挂 ErrorCard，无宿主（宿主级行为在
  // error_card_host_test.dart 与本文件 hit-test 组覆盖）。
  Widget buildCard(ErrorReport report, {int totalCount = 1}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: ErrorCard(report: report, totalCount: totalCount),
      ),
    ),
  );

  // 确定性 reporter：clock/eventId 固定，mediaPath 注入完整路径供脱敏边界
  // 断言，location 用注入 enricher 固定（不读真实文件系统）。
  ErrorReporterImpl makeReporter({
    ErrorLocationEnricher? locationEnricher,
    String? mediaPath,
  }) {
    var sequence = 0;
    return ErrorReporterImpl.forTesting(
      clock: FakeClock(DateTime.utc(2026, 8, 28, 12, 30, 45)),
      eventIdGenerator: () => 'card-${++sequence}',
      currentMediaPath: () => mediaPath,
      locationEnricher:
          locationEnricher ??
          (_) => ErrorLocation(
            primaryFrame: const ErrorLocationFrame(
              file: 'package:simple_player_flutter/lib/main.dart',
              packageScheme: 'package:',
              package: 'simple_player_flutter',
              packagePath: 'lib/main.dart',
              line: 42,
              column: 8,
              member: 'main',
            ),
            sourceLines: const [
              '40: // 前文注释',
              '41: void boom() {',
              '42:   throw StateError(boom);',
            ],
          ),
    );
  }

  // 报告 → 呈现队首（flushPresentation 后 current 才非空）。
  ErrorReport acceptHead(ErrorReporterImpl reporter, void Function() report) {
    report();
    reporter.flushPresentation();
    final state = reporter.presentation.value;
    final head = state.current;
    expect(head, isNotNull, reason: 'flushPresentation 后队首必须可呈现');
    return head!;
  }

  // 严重级色点 finder：BoxDecoration(shape: circle, color: expected)。
  Finder severityDot(Color color) => find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == color &&
        (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  group('expand 折叠/展开详情（CARD-03/D-03/D-04）', () {
    testWidgets('collapsed shows localized message, severity dot and basename', (
      tester,
    ) async {
      // Arrange：PlayerError 经真实 intake 接纳 —— 已知 l10nKey 应解析为
      // 本地化文案（MIG-01 迁移基线），mediaPath 全路径脱敏为 basename。
      final reporter = makeReporter(
        mediaPath: r'D:\media\movies\big buck bunny.mp4',
      );
      final report = acceptHead(reporter, () {
        reporter.reportPlayerError(
          FileError(FileErrorCode.fileNotFound, r'raw path D:\media\secret.mp4'),
        );
      });

      // Act：渲染折叠态卡片。
      await tester.pumpWidget(buildCard(report));

      // Assert：l10nKey → 「文件不存在」（zh locale），raw message 不出现。
      expect(find.text('文件不存在'), findsOneWidget);
      expect(find.textContaining(r'D:\media\secret.mp4'), findsNothing);
      // D-07：折叠区媒体路径只允许 basename 形态。
      expect(find.text('big buck bunny.mp4'), findsOneWidget);
      expect(find.textContaining(r'D:\media\movies'), findsNothing);
      // D-03：error 严重级 → Tokens.danger 色点。
      expect(severityDot(Tokens.danger), findsOneWidget);
    });

    testWidgets('whole-card tap expands five sections in D-04 order', (
      tester,
    ) async {
      // Arrange：折叠态可见，chevron 朝下。
      final reporter = makeReporter();
      final stackText =
          '#0      boom (package:simple_player_flutter/lib/main.dart:42:8)\n'
          '#1      handler (dart:async/zone.dart:1:1)';
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('引擎打开失败'), StackTrace.fromString(stackText));
      });
      await tester.pumpWidget(buildCard(report));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Act：整卡点击（点 message 文本区，避开徽标/chevron 自身手势）。
      await tester.tapAt(tester.getCenter(find.text('Bad state: 引擎打开失败')));
      await tester.pump();

      // Assert：chevron 翻转，五段齐备。
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      // ① 定位：file:line。
      expect(find.textContaining('lib/main.dart:42'), findsOneWidget);
      // ② 源码行：lineNumber: text 逐行展示。
      expect(find.textContaining('41: void boom() {'), findsOneWidget);
      expect(find.textContaining('42:   throw StateError(boom);'), findsOneWidget);
      // ③ 调用栈：rawStackTrace 逐字符原样（terminal 语义，无二次处理）。
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == report.rawStackTrace,
        ),
        findsOneWidget,
      );
      // ④ 日志路径：无 diagnosticLogStatus → 降级文案。
      expect(find.text('日志文件不可用'), findsOneWidget);
      // ⑤ 重复信息。
      expect(find.text('重复 1 次'), findsOneWidget);
      expect(find.textContaining('2026-08-28T12:30:45'), findsOneWidget);

      // D-04 段序：定位 → 源码行 → 调用栈 → 日志文件 → 重复。
      double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(topOf('定位'), lessThan(topOf('源码行')));
      expect(topOf('源码行'), lessThan(topOf('调用栈')));
      expect(topOf('调用栈'), lessThan(topOf('日志文件')));
      expect(topOf('日志文件'), lessThan(topOf('重复 1 次')));

      // Act：再点收起。
      await tester.tapAt(tester.getCenter(find.text('Bad state: 引擎打开失败')));
      await tester.pump();

      // Assert：回到折叠态，展开段全部消失。
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(find.text('定位'), findsNothing);
      expect(find.text('调用栈'), findsNothing);
    });

    testWidgets('null location degrades to location-unavailable text', (
      tester,
    ) async {
      // Arrange：D-05 fallback —— 栈中无项目帧时 location 为 null。
      final reporter = makeReporter(locationEnricher: (_) => null);
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('无项目帧'), StackTrace.current);
      });
      await tester.pumpWidget(buildCard(report));

      // Act：展开。
      await tester.tapAt(tester.getCenter(find.text('Bad state: 无项目帧')));
      await tester.pump();

      // Assert：降级文本出现，不抛错；其余段（栈/日志/重复）不缺。
      expect(find.text('定位不可用'), findsOneWidget);
      expect(find.text('调用栈'), findsOneWidget);
      expect(find.text('日志文件'), findsOneWidget);
      expect(find.text('重复 1 次'), findsOneWidget);
      // 无 location 即无源码行可展示：源码行段不渲染。
      expect(find.text('源码行'), findsNothing);
    });

    testWidgets('full media path never rendered in visible tree (T-03-05)', (
      tester,
    ) async {
      // Arrange：报告携带完整媒体路径快照（fullMediaPath 字段存在）。
      const fullPath = r'D:\media\movies\big buck bunny.mp4';
      final reporter = makeReporter(mediaPath: fullPath);
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('路径脱敏检查'), StackTrace.current);
      });
      expect(report.fullMediaPath, fullPath);

      // Act：折叠渲染。
      await tester.pumpWidget(buildCard(report));

      // Assert：折叠树中完整路径不出现，basename 照常显示。
      expect(find.textContaining(fullPath), findsNothing);
      expect(find.text('big buck bunny.mp4'), findsOneWidget);

      // Act：展开后同样不得出现。
      await tester.tapAt(tester.getCenter(find.text('Bad state: 路径脱敏检查')));
      await tester.pump();

      expect(find.textContaining(fullPath), findsNothing);
    });

    testWidgets('unknown l10nKey falls back to raw message', (tester) async {
      // Arrange：未知 key（如未来新增错误码未同步解析表）→ raw message。
      // 任何 intake 边界都产不出未知 key，故直接构造不可变报告快照。
      final timestamp = DateTime.utc(2026, 8, 28, 12, 30, 45);
      final report = ErrorReport(
        eventId: 'unknown-key',
        source: ErrorSource.playerEngine,
        severity: ErrorSeverity.error,
        firstOccurredAt: timestamp,
        lastOccurredAt: timestamp,
        errorType: 'FileError',
        playerErrorCode: 'file:nonexistentCode',
        message: 'raw fallback message',
        rawStackTrace: '#0 fake (fake.dart:1:1)',
        mediaPath: null,
        occurrenceCount: 1,
      );

      // Act / Assert：折叠态显示 raw message 而非抛错或空白。
      await tester.pumpWidget(buildCard(report));
      expect(find.text('raw fallback message'), findsOneWidget);
    });

    testWidgets('warning and fatal severities map to dedicated tokens (D-03)', (
      tester,
    ) async {
      // Arrange：fatal 经真实 intake（pathTraversal 不可恢复 → fatal）；
      // warning 当前无捕获源产出（D-02），直接构造不可变快照覆盖映射。
      final reporter = makeReporter();
      final fatalReport = acceptHead(reporter, () {
        reporter.reportPlayerError(
          FileError(FileErrorCode.pathTraversal, '路径遍历攻击'),
        );
      });
      final timestamp = DateTime.utc(2026, 8, 28, 12, 30, 45);
      final warningReport = ErrorReport(
        eventId: 'warning-severity',
        source: ErrorSource.playerEngine,
        severity: ErrorSeverity.warning,
        firstOccurredAt: timestamp,
        lastOccurredAt: timestamp,
        errorType: 'FileError',
        playerErrorCode: 'file:pathEmpty',
        message: '降级警告',
        rawStackTrace: '#0 fake (fake.dart:1:1)',
        mediaPath: null,
        occurrenceCount: 1,
      );

      // Act / Assert：fatal → 深红 token；warning → amber token；
      // 三值均有 token 来源（error 值已在第一用例断言 Tokens.danger）。
      await tester.pumpWidget(buildCard(fatalReport));
      expect(severityDot(Tokens.dangerFatal), findsOneWidget);
      expect(severityDot(Tokens.danger), findsNothing);

      await tester.pumpWidget(buildCard(warningReport));
      expect(severityDot(Tokens.warning), findsOneWidget);
      expect(severityDot(Tokens.dangerFatal), findsNothing);
    });

    testWidgets('log path renders from diagnosticLogPath when available', (
      tester,
    ) async {
      // Arrange：重建单例并注入提供路径的 DiagnosticLogStatus fake。
      await ErrorReporterImpl.resetForTesting();
      ErrorReporterImpl.init(diagnosticLogStatus: _FakeLogStatus('C:/logs/diag.txt'));
      final reporter = makeReporter();
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('日志路径检查'), StackTrace.current);
      });
      await tester.pumpWidget(buildCard(report));

      // Act：展开。
      await tester.tapAt(tester.getCenter(find.text('Bad state: 日志路径检查')));
      await tester.pump();

      // Assert：显示真实日志路径而非降级文案。
      expect(find.text('C:/logs/diag.txt'), findsOneWidget);
      expect(find.text('日志文件不可用'), findsNothing);
    });
  });
}

/// DiagnosticLogStatus 测试替身 —— 提供固定日志路径（fakes-over-mocks）。
class _FakeLogStatus implements DiagnosticLogStatus {
  _FakeLogStatus(String path) : _logPath = ValueNotifier<String?>(path);

  final ValueNotifier<bool> _logsAvailable = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _logPath;

  @override
  ValueListenable<bool> get logsAvailable => _logsAvailable;

  @override
  ValueListenable<String?> get logPath => _logPath;
}
