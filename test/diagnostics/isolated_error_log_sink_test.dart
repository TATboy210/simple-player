/// IsolatedErrorLogSink 端到端测试 —— 真实 isolate + 真实临时文件纵切。
///
/// End-to-end tests for the logging-isolate sink: a real worker isolate
/// persists formatted diagnostic packs to a real temporary file, and the
/// degradation paths fall back to the frozen ErrorLogFileSink contract.
/// The `_LogFixture` / `_report` helpers are locally replicated (tests must
/// not import private symbols from sibling test files).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/isolated_error_log_sink.dart';

void main() {
  group('IsolatedErrorLogSink', () {
    test(
      'persists error records through the logging isolate in record order',
      () async {
        // Arrange
        final fixture = await _LogFixture.create();
        addTearDown(fixture.dispose);
        final sink = IsolatedErrorLogSink(file: fixture.file);

        // Act — 两条 error 直接 record + 一条 warning（severity 门应拦截）。
        sink.record(
          _report(message: '第一条中文错误记录', rawStack: 'first raw stack'),
          ReportAcceptance.newReport,
        );
        sink.record(
          _report(
            severity: ErrorSeverity.warning,
            eventId: 'warning-id',
            message: '警告证据不落盘',
          ),
          ReportAcceptance.newReport,
        );
        sink.record(
          _report(
            eventId: 'event-2',
            message: '第二条中文错误记录',
            rawStack: 'second raw stack',
          ),
          ReportAcceptance.newReport,
        );
        await sink.drain();

        // Assert — record 序 = 落盘序；warning 被门拦截；无心跳行乱入
        // （默认 30s 心跳在快测内不触发，顺带锁定心跳不经 severity 门）。
        final contents = await fixture.file.readAsString();
        final firstOffset = contents.indexOf('第一条中文错误记录');
        final secondOffset = contents.indexOf('第二条中文错误记录');
        expect(firstOffset, greaterThanOrEqualTo(0));
        expect(secondOffset, greaterThan(firstOffset));
        expect(contents, isNot(contains('警告证据不落盘')));
        expect(contents, endsWith('second raw stack\n\n'));
        expect(contents, isNot(contains('main alive')));
        expect(sink.logsAvailable.value, isTrue);
        await sink.dispose();
      },
    );

    test('drain is reusable and dispose is idempotent', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(file: fixture.file);

      // Act — 连发 3 条后 drain 两次；dispose 两次。
      for (var index = 0; index < 3; index += 1) {
        sink.record(
          _report(eventId: 'event-$index', message: 'message-$index'),
          ReportAcceptance.newReport,
        );
      }
      await sink.drain();
      await sink.drain();
      await sink.dispose();
      await sink.dispose();

      // Assert — 全部落盘且无异常挂死。
      final contents = await fixture.file.readAsString();
      expect(contents, contains('message-2'));
      expect(sink.logsAvailable.value, isTrue);
    });

    test('records after dispose fall back to direct write', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(file: fixture.file);

      // Act — record → dispose → 再 record（对应「effect remains reusable」
      // 契约：关断后记录经回退 ErrorLogFileSink 直写，不丢失）。
      sink.record(
        _report(eventId: 'before-close', message: '关断前记录'),
        ReportAcceptance.newReport,
      );
      await sink.dispose();
      sink.record(
        _report(eventId: 'after-close', message: '关断后记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();

      // Assert
      final contents = await fixture.file.readAsString();
      expect(contents, contains('关断前记录'));
      expect(contents, contains('关断后记录'));
    });

    test(
      'contains real write failures, recovers availability, and reports once',
      () async {
        // Arrange
        final fixture = await _LogFixture.create();
        addTearDown(fixture.dispose);
        final failures = <Object>[];
        final sink = IsolatedErrorLogSink(
          file: fixture.file,
          degradedOutput: (error, _) => failures.add(error),
        );

        // Act — 先成功落盘，再删除整个目录制造真实写失败，再重建目录证明
        // 每消息现开句柄可恢复（镜像既有「restores availability」用例）。
        sink.record(_report(message: '删除前记录'), ReportAcceptance.newReport);
        await sink.drain();
        await fixture.directory.delete(recursive: true);
        sink.record(
          _report(eventId: 'gone', message: '删除后记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();
        final unavailableAfterFailure = sink.logsAvailable.value;

        await fixture.directory.create(recursive: true);
        sink.record(
          _report(eventId: 'back', message: '重建后记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();

        // Assert
        expect(unavailableAfterFailure, isFalse);
        expect(sink.logsAvailable.value, isTrue);
        expect(failures, hasLength(1));
        final contents = await fixture.file.readAsString();
        expect(contents, contains('重建后记录'));
        await sink.dispose();
      },
    );

    test('rate-limits fifty consecutive real failures', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final failures = <Object>[];
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        degradedOutput: (error, _) => failures.add(error),
      );
      await fixture.directory.delete(recursive: true);

      // Act — 目录缺失期间连发 50 条（每条现开句柄都真实失败）。
      for (var index = 0; index < 50; index += 1) {
        sink.record(
          _report(eventId: 'failure-$index'),
          ReportAcceptance.newReport,
        );
      }
      await sink.drain();
      await sink.dispose();

      // Assert — 首条 + 第 50 条恰好两次限流上报。
      expect(failures, hasLength(2));
      expect(sink.logsAvailable.value, isFalse);
    });

    test(
      'rolls the grown active log to error.log.1 at the byte threshold',
      () async {
        // Arrange — 阈值注入 400 字节：单个诊断包的固定分段开销已越阈，
        // 无需大体积夹具即可驱动滚动。
        final fixture = await _LogFixture.create();
        addTearDown(fixture.dispose);
        final sink = IsolatedErrorLogSink(file: fixture.file, maxLogBytes: 400);
        final archive = File('${fixture.directory.path}/error.log.1');

        // Act — 第 1 条把活动文件写越阈；第 2 条在追加前触发滚动（rename
        // 到 .1 后在全新 error.log 上继续写）。
        sink.record(
          _report(eventId: 'early', message: '第一条滚动的中文错误记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();
        sink.record(
          _report(eventId: 'late', message: '第二条落入新文件的中文错误记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();

        // Assert — 归档留存早期证据，活动文件只含后期证据，可用性恒真。
        expect(archive.existsSync(), isTrue);
        final archiveContents = archive.readAsStringSync();
        final activeContents = fixture.file.readAsStringSync();
        expect(archiveContents, contains('第一条滚动的中文错误记录'));
        expect(archiveContents, isNot(contains('第二条落入新文件的中文错误记录')));
        expect(activeContents, contains('第二条落入新文件的中文错误记录'));
        expect(activeContents, isNot(contains('第一条滚动的中文错误记录')));
        expect(sink.logsAvailable.value, isTrue);
        await sink.dispose();
      },
    );

    test(
      'replaces the previous archive so only one .1 generation exists',
      () async {
        // Arrange — 同一阈值；三条记录制造两次滚动，验证单代归档策略。
        final fixture = await _LogFixture.create();
        addTearDown(fixture.dispose);
        final sink = IsolatedErrorLogSink(file: fixture.file, maxLogBytes: 400);

        // Act — 第 2 条触发第一次滚动，第 3 条触发第二次（覆盖旧归档）。
        sink.record(
          _report(eventId: 'roll-1', message: '第一代归档记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();
        sink.record(
          _report(eventId: 'roll-2', message: '第二代归档记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();
        sink.record(
          _report(eventId: 'roll-3', message: '最终活动记录'),
          ReportAcceptance.newReport,
        );
        await sink.drain();

        // Assert — 目录里恰好一个 .1 文件，内容是第二次滚动的归档；
        // 早期证据随单代策略被替换（有意为之的存储上界）。
        final archives = fixture.directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.1'))
            .toList();
        expect(archives, hasLength(1));
        final archiveContents = archives.single.readAsStringSync();
        expect(archiveContents, contains('roll-2'));
        expect(archiveContents, contains('第二代归档记录'));
        expect(archiveContents, isNot(contains('第一代归档记录')));
        expect(archiveContents, isNot(contains('最终活动记录')));
        expect(fixture.file.readAsStringSync(), contains('最终活动记录'));
        expect(sink.logsAvailable.value, isTrue);
        await sink.dispose();
      },
    );

    test('archives an oversized pre-existing log at worker startup', () async {
      // Arrange — 上一会话遗留的超限日志先种入，再构造 sink（阈值 400）。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      const seeded = 'seeded-legacy-log-';
      fixture.file.writeAsStringSync(seeded * 60);
      final archive = File('${fixture.directory.path}/error.log.1');
      final sink = IsolatedErrorLogSink(file: fixture.file, maxLogBytes: 400);

      // Act — 会话首条记录 + drain。worker 在握手后同步执行启动归档
      // （send 与 roll 之间无 await），main 收到握手时归档已完成。
      sink.record(
        _report(eventId: 'fresh', message: '新会话首条记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();

      // Assert — 种入字节整体进入归档，首条记录落在全新活动文件。
      expect(archive.existsSync(), isTrue);
      final archiveContents = archive.readAsStringSync();
      expect(archiveContents, contains('seeded-legacy-log-'));
      expect(archiveContents, isNot(contains('新会话首条记录')));
      final activeContents = fixture.file.readAsStringSync();
      expect(activeContents, contains('新会话首条记录'));
      expect(activeContents, isNot(contains('seeded-legacy-log-')));
      expect(sink.logsAvailable.value, isTrue);
      await sink.dispose();
    });

    test('archive bytes equal the appended bytes and rotation never flips availability', () async {
      // Arrange — 监听可用性 notifier 的全部变化（滚动不得产生翻转）。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final availability = <bool>[];
      final sink = IsolatedErrorLogSink(file: fixture.file, maxLogBytes: 400);
      sink.logsAvailable.addListener(
        () => availability.add(sink.logsAvailable.value),
      );

      // Act — 第 1 条落盘后抓取活动文件字节；第 2 条触发滚动。
      sink.record(
        _report(eventId: 'bytes-1', message: '滚动前字节样本'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      final appended = fixture.file.readAsBytesSync();
      sink.record(
        _report(eventId: 'bytes-2', message: '触发滚动的第二条'),
        ReportAcceptance.newReport,
      );
      await sink.drain();

      // Assert — 归档与滚动前活动文件逐字节一致（rename 不改写）；
      // 可用性读数零翻转（滚动不是写失败）。
      final archive = File('${fixture.directory.path}/error.log.1');
      expect(archive.readAsBytesSync(), appended);
      expect(availability, isEmpty);
      expect(sink.logsAvailable.value, isTrue);
      await sink.dispose();
    });

    test('writes heartbeat lines through the logging isolate', () async {
      // Arrange — 心跳间隔注入 1ms；真实 Timer 走主 isolate 事件循环。
      // 活动期契约：先种入一条真实记录（解锁心跳门槛），再观察心跳落盘。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        heartbeatInterval: const Duration(milliseconds: 1),
      );

      // Act — 真实记录 + drain 后，真实等待让后续 tick 到达 worker 落盘。
      sink.record(
        _report(eventId: 'activity', message: '活动期记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sink.dispose();

      // Assert — 日志文件出现可 grep 的心跳行（冻结格式不变）。
      final contents = await fixture.file.readAsString();
      expect(contents, contains('main alive @'));
      expect(sink.logsAvailable.value, isTrue);
    });

    test('idle heartbeat ticks write nothing between activity periods', () async {
      // Arrange — 1ms 心跳间隔放大 tick 数；纯空闲窗口内文件必须零增长。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        heartbeatInterval: const Duration(milliseconds: 1),
      );

      // Act — 种入一条真实记录并 drain，等首个 tick 消费掉活动门槛
      // （20ms ≫ 1ms 间隔，写入早已落盘），再进入纯空闲窗口。
      sink.record(
        _report(eventId: 'seed', message: '空闲前记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sink.drain();
      final lengthBefore = fixture.file.lengthSync();
      final heartbeatCountBefore =
          'main alive @'.allMatches(fixture.file.readAsStringSync()).length;

      // 纯空闲窗口横跨数十个 tick（约 60 个）。
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sink.drain();

      // Assert — 空闲 tick 零写盘：文件字节长度与心跳行数恒定。
      final contentsAfter = fixture.file.readAsStringSync();
      expect(fixture.file.lengthSync(), lengthBefore);
      expect(
        'main alive @'.allMatches(contentsAfter).length,
        heartbeatCountBefore,
      );
      expect(sink.logsAvailable.value, isTrue);
      await sink.dispose();
    });

    test('idle suppression gate resets on the next real record', () async {
      // Arrange — 同一 1ms 心跳缝；门槛在真实派发后重置。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        heartbeatInterval: const Duration(milliseconds: 1),
      );

      // Act — 种入记录 → 等 20ms 消费门槛 → 记录空闲基线（行数 + 长度）。
      sink.record(
        _report(eventId: 'seed', message: '初始记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sink.drain();
      final baselineLength = fixture.file.lengthSync();
      final baselineCount =
          'main alive @'.allMatches(fixture.file.readAsStringSync()).length;

      // 纯空闲窗口：基线必须纹丝不动。
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sink.drain();
      expect(fixture.file.lengthSync(), baselineLength);
      expect(
        'main alive @'.allMatches(fixture.file.readAsStringSync()).length,
        baselineCount,
      );

      // 新真实记录解锁门槛：下一个 tick 恰好补一条心跳，随后继续抑制。
      sink.record(
        _report(eventId: 'wake', message: '唤醒记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sink.drain();

      // Assert — 恰好多出一条心跳行（格式不变），唤醒记录已落盘。
      final contentsAfter = fixture.file.readAsStringSync();
      expect(
        'main alive @'.allMatches(contentsAfter).length,
        baselineCount + 1,
      );
      expect(contentsAfter, contains('唤醒记录'));
      expect(sink.logsAvailable.value, isTrue);
      await sink.dispose();
    });

    test(
      'spawn failure degrades silently and writes via direct fallback',
      () async {
        // Arrange — spawnWorker 注入同步抛 StateError 的假缝。
        final fixture = await _LogFixture.create();
        addTearDown(fixture.dispose);
        final failures = <Object>[];
        final sink = IsolatedErrorLogSink(
          file: fixture.file,
          degradedOutput: (error, _) => failures.add(error),
          spawnWorker: (entry, config, {onExit, onError}) =>
              throw StateError('spawn blocked'),
        );

        // Act — record 两条（降级后经回退直写）→ drain。
        sink.record(_report(message: '缓冲一'), ReportAcceptance.newReport);
        sink.record(
          _report(eventId: 'second', message: '缓冲二'),
          ReportAcceptance.newReport,
        );
        await sink.drain();

        // Assert — 降级是模式切换非写失败：零 degradedOutput、可用性 true。
        final contents = await fixture.file.readAsString();
        expect(contents, contains('缓冲一'));
        expect(contents, contains('缓冲二'));
        expect(sink.logsAvailable.value, isTrue);
        expect(failures, isEmpty);
      },
    );

    test('unexpected worker death degrades and keeps recording', () async {
      // Arrange — passthrough 假缝捕获真 Isolate 供 kill。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final failures = <Object>[];
      Isolate? worker;
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        degradedOutput: (error, _) => failures.add(error),
        spawnWorker: (entry, config, {onExit, onError}) async {
          final isolate = await Isolate.spawn(
            entry,
            config,
            onExit: onExit,
            onError: onError,
            errorsAreFatal: false,
          );
          worker = isolate;
          return isolate;
        },
      );

      // Act — 先正常落盘，再杀死 worker，真实轮询降级标志（上限 2s，
      // 消除 kill→onExit 竞态）。
      sink.record(_report(message: '死亡前记录'), ReportAcceptance.newReport);
      await sink.drain();
      worker?.kill(priority: Isolate.immediate);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!sink.isDegradedForTesting && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Assert — 降级后记录经回退直写不丢失。
      expect(sink.isDegradedForTesting, isTrue);
      sink.record(
        _report(eventId: 'after-death', message: '死亡后记录'),
        ReportAcceptance.newReport,
      );
      await sink.drain();
      final contents = await fixture.file.readAsString();
      expect(contents, contains('死亡后记录'));
      await sink.dispose();
    });
  });
}

/// Builds a direct report input for sink-construction tests.
ErrorReport _report({
  ErrorSeverity severity = ErrorSeverity.error,
  String eventId = 'event-1',
  String message = 'error evidence',
  String rawStack = 'raw stack\npackage:simple_player_flutter/test.dart:7',
}) {
  final occurredAt = DateTime.utc(2026, 8, 30, 12);
  return ErrorReport(
    eventId: eventId,
    source: ErrorSource.platformDispatcher,
    severity: severity,
    firstOccurredAt: occurredAt,
    lastOccurredAt: occurredAt,
    errorType: 'StateError',
    playerErrorCode: null,
    message: message,
    rawStackTrace: rawStack,
    mediaPath: null,
    occurrenceCount: 1,
  );
}

/// Owns a unique temporary directory for a real-file integration test.
final class _LogFixture {
  const _LogFixture(this.directory, this.file);

  final Directory directory;
  final File file;

  /// Creates an empty durable target rather than relying on in-memory fakes.
  static Future<_LogFixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'isolated-log-sink-',
    );
    return _LogFixture(directory, File('${directory.path}/error.log'));
  }

  /// Cleans the test-owned temporary directory; tolerates mid-test deletion
  /// (failure-path tests delete the directory to simulate disk loss).
  Future<void> dispose() async {
    if (!directory.existsSync()) {
      return;
    }
    await directory.delete(recursive: true);
  }
}
