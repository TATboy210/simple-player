/// 爆发压测补差与关闭失败隔离补差(VER-02/VER-03, D-03/D-04)。
///
/// Burst-resilience gap tests (VER-02/VER-03, D-03/D-04). Existing primary
/// evidence is referenced, not rewritten:
/// - 100/1000 duplicate burst: error_reporter_test.dart#
///   'keeps 100 and 1000 duplicate bursts bounded with accumulated counts'
/// - FIFO ≤5 单点: error_reporter_test.dart#
///   'evicts the sixth distinct head, dismisses FIFO head, and flushes idempotently'
/// - reentrancy/effect 失败隔离: error_reporter_test.dart#
///   'isolates listener and effect failures while suppressing reentrant intake'
/// - 复制失败隔离: error_card_test.dart#
///   'unmocked clipboard channel leaves card intact with no crash'
///
/// 本文件补既有覆盖与 D-03/D-04 口径之间的差距:
/// A) 混合爆发(互异+合并)下 FIFO ≤5、逐出不可见、合并计数可见、零 unhandled;
/// B) 爆发下写盘受控 —— 单写者链不断、包完整有序、无交错损坏;
/// C) 爆发后预排定 timer/microtask 在测试预算内准时完成(实机面由
///    03-UAT Test 1 归档佐证);
/// D) close-advance 触发 failing effect 不抛第二错误(既有 :743 只覆盖
///    intake 路径,dismiss 路径此前无用例显式锁死 —— 条件补差命中)。
///
/// D-04 明确排除:不设 profile/内存曲线阈值(后端优化轮 Deferred Ideas)。
library;

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';

void main() {
  /// 构造确定性 reporter(先例 error_reporter_test _reporter 同款)。
  ErrorReporterImpl reporter({
    Clock? clock,
    List<ErrorReportEffect> effects = const [],
    DiagnosticLogStatus? diagnosticLogStatus,
    LastResortOutput? lastResortOutput,
  }) {
    var sequence = 0;
    return ErrorReporterImpl.forTesting(
      clock: clock ?? FakeClock(DateTime.utc(2026, 8, 28)),
      eventIdGenerator: () => 'burst-${++sequence}',
      currentMediaPath: () => 'burst.mp4',
      effects: effects,
      diagnosticLogStatus: diagnosticLogStatus,
      lastResortOutput: lastResortOutput ?? (_, _) {},
    );
  }

  /// 项目本地栈行(与既有套件同款,稳定指纹)。
  StackTrace stack(String file) =>
      StackTrace.fromString('package:simple_player_flutter/$file:1');

  group('混合爆发有界性(VER-02, D-03/D-04)', () {
    test(
      'keeps a 1000 mixed burst bounded with visible merge counts and zero '
      'unhandled errors',
      () {
        // Arrange:互异 900 条 + 同消息 100 条(固定时钟窗内合并);
        // unhandled 口径 = zone 未捕获 + FlutterError.onError 双计数为零。
        final subject = reporter();
        final zoneErrors = <Object>[];
        final flutterErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = flutterErrors.add;
        addTearDown(() => FlutterError.onError = originalOnError);

        // Act:1000 条合成事件爆发(既有 100/1000 duplicate burst 主证据的
        // 混合形态补差 —— 互异流挤 FIFO,重复流验合并计数)。
        expect(
          () => runZonedGuarded(() {
            for (var index = 0; index < 900; index += 1) {
              subject.reportPlatformSafely(
                StateError('burst-${index.toString().padLeft(3, '0')}'),
                stack('mixed.dart'),
              );
            }
            for (var index = 0; index < 100; index += 1) {
              subject.reportPlatformSafely(
                StateError('burst-storm-dup'),
                stack('mixed.dart'),
              );
            }
          }, (error, stackTrace) => zoneErrors.add(error)),
          returnsNormally,
        );

        // Assert:FIFO 有界 ≤5(设计值)。
        expect(subject.queuedReports.length, lessThanOrEqualTo(5));
        expect(subject.queuedReports, hasLength(5));
        // Assert:被逐出报告不再在队列(队首/中段样本)。
        final messages = subject.queuedReports
            .map((report) => report.message)
            .toList();
        expect(messages, isNot(contains('Bad state: burst-000')));
        expect(messages, isNot(contains('Bad state: burst-100')));
        // Assert:合并报告的 occurrenceCount 可见(100 次重复合并为一份)。
        final merged = subject.queuedReports.singleWhere(
          (report) => report.message == 'Bad state: burst-storm-dup',
        );
        expect(merged.occurrenceCount, 100);
        // Assert:无 unhandled error(zone 与框架双口径为零)。
        expect(zoneErrors, isEmpty);
        expect(flutterErrors, isEmpty);
      },
    );
  });

  group('爆发下写盘受控(VER-02, D-03/D-04)', () {
    test('keeps the single-writer chain intact with ordered packs under burst',
        () async {
      // Arrange:temp 目录真实 FileSink(先例 error_log_file_sink_test);
      // degradedOutput 收集缝证明零写失败。
      final root = await Directory.systemTemp.createTemp('burst_resilience');
      final target = File('${root.path}${Platform.pathSeparator}error.log');
      final writeFailures = <Object>[];
      final sink = ErrorLogFileSink(
        file: target,
        degradedOutput: (error, stackTrace) => writeFailures.add(error),
      );
      final delegate = DelegatingDiagnosticLogEffect();
      final subject = reporter(
        effects: [delegate.record],
        diagnosticLogStatus: delegate,
      );
      delegate.activate(sink: sink, resolvedPath: target.path);
      addTearDown(() async {
        await delegate.dispose();
        await root.delete(recursive: true);
      });

      // Act:100 条互异爆发(D-03 频带 100–1000 下限;B 侧重写盘而非队列)。
      for (var index = 0; index < 100; index += 1) {
        subject.reportPlatformSafely(
          StateError('burst-${index.toString().padLeft(3, '0')}'),
          stack('disk.dart'),
        );
      }
      await sink.drain();
      final contents = await target.readAsString();

      // Assert:100 份诊断证据全部落盘、按报告序、无交错损坏。
      // (诊断包内部以空行分节,不能按空行切包计数;改为逐标记断言
      // 恰好出现一次 + 文件内位置严格递增 —— 单写者 Future 链保序。)
      var previousPosition = -1;
      for (var index = 0; index < 100; index += 1) {
        final marker = 'burst-${index.toString().padLeft(3, '0')}';
        final matches = RegExp(marker).allMatches(contents).toList();
        expect(matches, hasLength(1), reason: '标记 $marker 应恰好出现一次');
        final position = matches.single.start;
        expect(position, greaterThan(previousPosition), reason: '$marker 应按序');
        previousPosition = position;
      }
      // Assert:无并发写冲突错误 —— 可用性为真、零降级输出。
      expect(sink.logsAvailable.value, isTrue);
      expect(writeFailures, isEmpty);
    });
  });

  group('pump 响应不卡(VER-02, D-03)', () {
    test('completes pre-scheduled timers and microtasks on time after burst',
        () {
      fakeAsync((async) {
        // Arrange:爆发前预排定 timer(50ms)—— 「播放控制仍响应」的
        // 自动化代理;爆发后追加 microtask 验事件循环不被饿死。
        var timerFires = 0;
        Timer(const Duration(milliseconds: 50), () => timerFires += 1);
        var microtaskRan = false;
        final subject = reporter();
        final burstStack = stack('pump.dart');

        // Act:1000 条爆发占用同步预算,随后排定 microtask 并推进时钟。
        for (var index = 0; index < 900; index += 1) {
          subject.reportPlatformSafely(
            StateError('pump-${index.toString().padLeft(3, '0')}'),
            burstStack,
          );
        }
        for (var index = 0; index < 100; index += 1) {
          subject.reportPlatformSafely(
            StateError('pump-storm-dup'),
            burstStack,
          );
        }
        scheduleMicrotask(() => microtaskRan = true);
        async.elapse(const Duration(milliseconds: 100));

        // Assert:timer 准时完成(1 次,不丢不重)、microtask 已刷新、
        // 队列在爆发后仍有界。
        expect(timerFires, 1);
        expect(microtaskRan, isTrue);
        expect(subject.queuedReports.length, lessThanOrEqualTo(5));
      });
    });
  });

  group('关闭失败隔离(VER-03 条件补差)', () {
    test('keeps close-advance contained when the effect fails', () {
      // Arrange:循 :743 reentrancy 先例的隔离缝 —— 失败 effect + 抛错
      // presentation 监听;预置两份报告使 close 有队首可消费、有后继可发布。
      final lastResort = <Object>[];
      late final ErrorReporterImpl subject;
      subject = reporter(
        lastResortOutput: (error, stackTrace) => lastResort.add(error),
        effects: [
          (_, _) => throw StateError('effect failed on close'),
          (_, _) {},
        ],
      );
      final originalOnError = FlutterError.onError;
      final listenerFailures = <FlutterErrorDetails>[];
      FlutterError.onError = listenerFailures.add;
      addTearDown(() => FlutterError.onError = originalOnError);
      subject.presentation.addListener(() => throw StateError('listener'));
      subject.reportPlatformSafely(StateError('close-head'), stack('close.dart'));
      subject.reportPlatformSafely(StateError('close-next'), stack('close.dart'));
      // intake 期的 effect 失败已被收容,清零后隔离口径只针对 close 路径。
      lastResort.clear();

      // Act:呈现就绪(先例 :156 flushPresentation 同款,_publishSafely
      // 保持 isReady 语义),随后关闭推进 —— 失败 effect 与抛错监听都
      // 不得外溢,更不得经 reentrant 路径把失败变成第二份错误报告。
      expect(subject.flushPresentation, returnsNormally);
      expect(subject.dismissCurrent, returnsNormally);

      // Assert:队列恰好推进一格(无第二错误入队);presentation 发布
      // 后继报告;抛错监听被 FlutterError.onError 边界收容(:743 同路由),
      // reporter 链自身零 last-resort 失败。
      expect(subject.queuedReports.map((report) => report.message), [
        'Bad state: close-next',
      ]);
      expect(
        subject.presentation.value.current?.message,
        'Bad state: close-next',
      );
      expect(listenerFailures, isNotEmpty); // 每次发布均被边界收容
      expect(lastResort, isEmpty);
    });
  });
}
