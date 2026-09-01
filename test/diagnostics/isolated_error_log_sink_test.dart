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

    test('writes heartbeat lines through the logging isolate', () async {
      // Arrange — 心跳间隔注入 1ms；真实 Timer 走主 isolate 事件循环。
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = IsolatedErrorLogSink(
        file: fixture.file,
        heartbeatInterval: const Duration(milliseconds: 1),
      );

      // Act — 真实等待让多次 tick 到达 worker 落盘。
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sink.dispose();

      // Assert — 日志文件出现可 grep 的心跳行。
      final contents = await fixture.file.readAsString();
      expect(contents, contains('main alive @'));
      expect(sink.logsAvailable.value, isTrue);
    });

    test('spawn failure degrades silently and writes via direct fallback',
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
    });

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
