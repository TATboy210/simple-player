import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostic_pack_formatter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
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

  // 宿主挂载 harness：复用 app.dart 的 buildErrorCardMount（与生产同一挂载
  // 语义），home 可注入探针/焦点节点（CARD-01/CARD-02 行为归宿主层级）。
  Widget buildMountHarness({required Widget home}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
    builder: buildErrorCardMount,
  );

  // 经单例接纳一份 bootstrap 报告并等一帧渲染。
  Future<void> showReport(WidgetTester tester, String message) async {
    ErrorReporterImpl.I.reportBootstrapSafely(
      StateError(message),
      StackTrace.current,
    );
    await tester.pump();
  }

  group('hit-test 卡片命中边界与 D-10 route 命中（CARD-02/D-10）', () {
    testWidgets('taps inside the card do not reach widgets below; taps outside pass through', (
      tester,
    ) async {
      // Arrange：卡片下方铺满一层点击探针（真实 Stack 层级复刻挂载形态）。
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
      await showReport(tester, '命中边界');
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：卡片矩形内点击（点 message 文本区，避开徽标/chevron 自身手势）。
      final inCardPoint = tester.getCenter(find.text('Bad state: 命中边界'));
      await tester.tapAt(inCardPoint);
      await tester.pump();

      // Assert：卡内点击被卡片吸收 —— 下层探针不触发，卡片自身收到（展开）。
      expect(probeTaps, 0);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

      // Act：卡片矩形外点击。
      await tester.tapAt(const Offset(600, 500));
      await tester.pump();

      // Assert：卡外点击穿透到下层控件；卡片展开态不变（未收到点击）。
      expect(probeTaps, 1);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('tap on route content above the navigator still hits while card visible (D-10)', (
      tester,
    ) async {
      // Arrange：卡片可见后 push 不透明 route（模拟 media_kit 全屏 route 层级）。
      var routeTaps = 0;
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      await showReport(tester, 'route 之下错误');
      expect(find.byType(ErrorCard), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Center(
                child: GestureDetector(
                  key: const ValueKey('route-probe'),
                  onTap: () => routeTaps++,
                  child: Container(width: 200, height: 100, color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act：点击 route 内容。
      await tester.tap(find.byKey(const ValueKey('route-probe')));
      await tester.pump();

      // Assert：D-10 —— 挂载层不吞 Navigator 命中；卡片仍在 route 之上可见。
      expect(routeTaps, 1);
      expect(find.byType(ErrorCard), findsOneWidget);
    });
  });

  group('close 常驻手动关与 FIFO 推进（CARD-01/CAP-04）', () {
    testWidgets('card persists across frames with no auto-hide timer', (
      tester,
    ) async {
      // Arrange：卡片可见。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      await showReport(tester, '常驻检查');
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：连续推进多帧时间（若存在自动隐藏 Timer，卡片会在此消失）。
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      // Assert：卡片常驻 —— 唯一消失途径为手动关闭。
      expect(find.byType(ErrorCard), findsOneWidget);
    });

    testWidgets('close button dismisses current and advances the FIFO', (
      tester,
    ) async {
      // Arrange：两份报告入队，卡片显示队首甲、徽标计总数。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('错误甲'),
        StackTrace.current,
      );
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('错误乙'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.textContaining('错误甲'), findsOneWidget);
      expect(find.text('2 错误'), findsOneWidget);

      // Act：点击关闭按钮。
      await tester.tap(find.byKey(const ValueKey('error-card-close')));
      await tester.pump();

      // Assert：CAP-04 —— 关闭推进到队首下一项，徽标计数减一。
      expect(find.textContaining('错误乙'), findsOneWidget);
      expect(find.text('1 错误'), findsOneWidget);

      // Act / Assert：再次关闭，单报告归零（卡片消失）。
      await tester.tap(find.byKey(const ValueKey('error-card-close')));
      await tester.pump();
      expect(find.byType(ErrorCard), findsNothing);
    });
  });

  group('focus 零焦点抢占（CARD-01/T-03-07）', () {
    testWidgets('primary focus unchanged after taps on collapsed, expanded and close button', (
      tester,
    ) async {
      // Arrange：home 带 autofocus 节点 —— KeyboardHandler 根焦点基准。
      final focusNode = FocusNode();
      await tester.pumpWidget(
        buildMountHarness(
          home: Focus(
            focusNode: focusNode,
            autofocus: true,
            child: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focusNode));
      await showReport(tester, '焦点检查');
      final messageCenter = tester.getCenter(find.text('Bad state: 焦点检查'));

      // Act / Assert：折叠态点击 → primaryFocus 不变。
      await tester.tapAt(messageCenter);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focusNode));

      // Act / Assert：展开态点击（含源码/栈文本区）→ primaryFocus 不变。
      final stackCenter = tester.getCenter(
        find.byWidgetPredicate((widget) => widget is SelectableText),
      );
      await tester.tapAt(stackCenter);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focusNode));

      // Act / Assert：关闭按钮点击 → primaryFocus 不变（卡片随之消失）。
      await tester.tap(find.byKey(const ValueKey('error-card-close')));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focusNode));
      expect(find.byType(ErrorCard), findsNothing);
    });

    testWidgets('card subtree has no focusable nodes and no GlassButton/FocusableActionDetector', (
      tester,
    ) async {
      // Arrange：卡片可见（经宿主挂载，ExcludeFocus 包裹生效）。
      await tester.pumpWidget(
        buildMountHarness(home: const Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      await showReport(tester, '结构检查');

      // Assert：卡片子树无焦点抢夺面。
      expect(
        find.descendant(
          of: find.byType(ErrorCard),
          matching: find.byType(GlassButton),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ErrorCard),
          matching: find.byType(FocusableActionDetector),
        ),
        findsNothing,
      );
      // 宿主 ExcludeFocus 的 Focus 节点：自身不可请求焦点且禁用后代焦点
      // （SelectableText 等内部节点被焦点系统整体屏蔽 —— primaryFocus 不变
      // 由上一用例行为断言锁死）。
      final hostFocus = tester.widget<Focus>(
        find.ancestor(of: find.byType(ErrorCard), matching: find.byType(Focus)).first,
      );
      expect(hostFocus.canRequestFocus, isFalse);
      expect(hostFocus.descendantsAreFocusable, isFalse);
    });
  });

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
      // ① 定位：file:line + 成员名（与实现渲染格式逐字符一致）。
      expect(
        find.text('package:simple_player_flutter/lib/main.dart:42  main'),
        findsOneWidget,
      );
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

  group('copy 一键复制诊断包与失败隔离（CARD-04/D-06）', () {
    // 注册 flutter/platform channel mock —— 同时是成功捕获与失败注入的缝
    // （03-VALIDATION Headless 基线：Clipboard 必须 mock channel 驱动而非
    // 真实剪贴板；未注册 handler 抛 MissingPluginException 正好构成天然
    // 失败路径）。测试结束自动摘除，避免污染后续用例。
    void mockPlatformChannel(
      WidgetTester tester,
      Future<Object?>? Function(MethodCall call)? handler,
    ) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        handler,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    // 推进 OSD hold 计时器（osdDefaultHoldMs=1200）：OsdService 是全局
    // 单例，show() 会启动 hide Timer —— 测试结束前不推进会遗留 pending
    // timer 导致 flutter_test 报错。
    Future<void> settleOsdTimer(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 2));

    testWidgets('copy sends a formatter-identical pack and shows copied OSD', (
      tester,
    ) async {
      // Arrange：真实 intake 报告 + 默认单例（无 diagnosticLogStatus →
      // logPath 为 null，与 formatter 对 null 的既有降级一致）。
      final reporter = makeReporter(mediaPath: r'D:\media\movies\bunny.mp4');
      final report = acceptHead(reporter, () {
        reporter.reportPlayerError(
          FileError(FileErrorCode.fileNotFound, 'raw path'),
        );
      });
      await tester.pumpWidget(buildCard(report));

      final calls = <MethodCall>[];
      mockPlatformChannel(tester, (call) async {
        calls.add(call);
        return null;
      });

      // Act：点击复制按钮。
      await tester.tap(find.byKey(const ValueKey('error-card-copy')));
      await tester.pump();

      // Assert：LOG-05 单一来源 —— 复制文本与 formatDiagnosticPack 输出
      // 逐字符相等（卡内禁止自拼格式字符串）。
      expect(calls, hasLength(1));
      expect(calls.single.method, 'Clipboard.setData');
      final arguments = calls.single.arguments! as Map<Object?, Object?>;
      expect(arguments['text'], formatDiagnosticPack(report));
      // D-06 成功反馈：OSD「已复制」pill。
      expect(OsdService.I.message.value?.text, '已复制');
      expect(OsdService.I.message.value?.icon, Icons.check);
      // 复制不改变折叠/展开状态，也不禁用卡片其余交互。
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await settleOsdTimer(tester);
    });

    testWidgets('pack logPath section reflects diagnosticLogPath at copy time', (
      tester,
    ) async {
      // Arrange：注入提供路径的 DiagnosticLogStatus fake，logPath 段应取
      // 该值（复制时刻取值，与展开区日志路径段同一读取路径）。
      await ErrorReporterImpl.resetForTesting();
      ErrorReporterImpl.init(diagnosticLogStatus: _FakeLogStatus('C:/logs/diag.txt'));
      final reporter = makeReporter();
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('日志路径复制'), StackTrace.current);
      });
      await tester.pumpWidget(buildCard(report));

      final calls = <MethodCall>[];
      mockPlatformChannel(tester, (call) async {
        calls.add(call);
        return null;
      });

      await tester.tap(find.byKey(const ValueKey('error-card-copy')));
      await tester.pump();

      final arguments = calls.single.arguments! as Map<Object?, Object?>;
      expect(
        arguments['text'],
        formatDiagnosticPack(report, logPath: 'C:/logs/diag.txt'),
      );
      expect(arguments['text'], contains('Path: C:/logs/diag.txt'));

      await settleOsdTimer(tester);
    });

    testWidgets('PlatformException injection shows failed OSD and keeps card intact', (
      tester,
    ) async {
      // Arrange：卡片可见后，把 channel mock 换成注入故障。
      final reporter = makeReporter();
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('复制隔离检查'), StackTrace.current);
      });
      await tester.pumpWidget(buildCard(report));
      mockPlatformChannel(
        tester,
        (call) async => throw PlatformException(code: 'copy_failed', message: 'injected'),
      );

      // Act。
      await tester.tap(find.byKey(const ValueKey('error-card-copy')));
      await tester.pump();

      // Assert：失败反馈 + 失败隔离 —— 卡片仍可见、内容不变、无异常外溢
      // （T-03-11：typed catch 吸收 PlatformException）。
      expect(OsdService.I.message.value?.text, '复制失败');
      expect(OsdService.I.message.value?.icon, Icons.error_outline);
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.text('Bad state: 复制隔离检查'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await settleOsdTimer(tester);
    });

    testWidgets('unmocked clipboard channel leaves card intact with no crash', (
      tester,
    ) async {
      // Arrange：不注册任何 handler —— channel 层真实语义验证。
      // 注（计划假设修正，见 03-03 SUMMARY）：SystemChannels.platform 是
      // OptionalMethodChannel，其 invokeMethod 内部**吞掉**
      // MissingPluginException 并返回 null；未注册 handler 的 send 在测试
      // binding 中更是永不完成。因此「未 mock → 复制失败」不可达，真实可断
      // 言行为是：复制调用不崩溃、卡片无恙；生产代码的
      // `on MissingPluginException` catch 保留作防御分支（不可经 channel 触达）。
      final reporter = makeReporter();
      final report = acceptHead(reporter, () {
        reporter.reportBootstrapSafely(StateError('缺插件检查'), StackTrace.current);
      });
      await tester.pumpWidget(buildCard(report));

      // Act。（两次 pump：让 tap 触发的异步链充分落地）
      await tester.tap(find.byKey(const ValueKey('error-card-copy')));
      await tester.pump();
      await tester.pump();

      // Assert：无崩溃、卡片可见且内容不变（无反馈 pill —— Future 未完成，
      // 真实桌面运行时引擎始终应答，不会出现此悬挂形态）。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.text('Bad state: 缺插件检查'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await settleOsdTimer(tester);
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
