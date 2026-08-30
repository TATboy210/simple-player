/// End-to-end tests for the durable ErrorReporter diagnostic-file effect.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

void main() {
  group('ErrorLogFileSink', () {
    test('persists an accepted platform report through the reporter effect', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = ErrorLogFileSink(file: fixture.file);
      final reporter = _reporter(effects: [sink.record]);
      final rawStack = 'raw stack\npackage:simple_player_flutter/test.dart:7';

      // Act
      reporter.reportPlatformSafely(
        StateError('中文错误'),
        StackTrace.fromString(rawStack),
      );
      await sink.drain();

      // Assert
      final contents = await fixture.file.readAsString();
      expect(contents, contains('== Report =='));
      expect(contents, contains('event-1'));
      expect(contents, contains('platformDispatcher'));
      expect(contents, contains('error'));
      expect(contents, contains('== Timing =='));
      expect(contents, contains('== Media =='));
      expect(contents, contains('== Location =='));
      expect(contents, contains('No project frame; see raw stack for details.'));
      expect(contents, contains('== Repetition =='));
      expect(contents, contains('== Log Path =='));
      expect(contents, contains(fixture.file.path));
      expect(contents, endsWith(rawStack));
    });

    test('appends UTF-8 records across sink instances in acceptance order', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final first = ErrorLogFileSink(file: fixture.file);
      final second = ErrorLogFileSink(file: fixture.file);
      final firstReporter = _reporter(effects: [first.record]);
      final secondReporter = _reporter(effects: [second.record]);

      // Act
      firstReporter.reportPlatformSafely(
        StateError('第一份中文记录'),
        StackTrace.fromString('first raw stack'),
      );
      await first.drain();
      secondReporter.reportPlatformSafely(
        StateError('第二份中文记录'),
        StackTrace.fromString('second raw stack'),
      );
      await second.drain();

      // Assert
      final contents = await fixture.file.readAsString();
      final firstOffset = contents.indexOf('第一份中文记录');
      final secondOffset = contents.indexOf('第二份中文记录');
      expect(firstOffset, greaterThanOrEqualTo(0));
      expect(secondOffset, greaterThan(firstOffset));
    });

    test('writes only error and fatal reports independently of presentation', () async {
      // Arrange
      final fixture = await _LogFixture.create();
      addTearDown(fixture.dispose);
      final sink = ErrorLogFileSink(file: fixture.file);
      final reporter = _reporter(effects: [sink.record]);

      // Act
      sink.record(_report(severity: ErrorSeverity.warning), ReportAcceptance.newReport);
      reporter.reportPlatformSafely(
        StateError('error evidence'),
        StackTrace.fromString('error stack'),
      );
      reporter.reportPlayerError(
        PlaybackError(
          PlaybackErrorCode.textureFailed,
          'fatal evidence',
        ),
        mediaPath: 'fatal.mp4',
      );
      reporter.flushPresentation();
      reporter.dismissCurrent();
      await sink.drain();

      // Assert
      final contents = await fixture.file.readAsString();
      expect(contents, isNot(contains('warning evidence')));
      expect(contents, contains('error evidence'));
      expect(contents, contains('fatal evidence'));
    });
  });
}

/// Constructs a deterministic reporter with a production-shaped effect seam.
ErrorReporterImpl _reporter({required List<ErrorReportEffect> effects}) {
  var sequence = 0;
  return ErrorReporterImpl.forTesting(
    clock: FakeClock(DateTime.utc(2026, 8, 30, 12)),
    eventIdGenerator: () => 'event-${++sequence}',
    currentMediaPath: () => 'current.mp4',
    effects: effects,
  );
}

/// Builds a direct warning input because capture boundaries only create errors.
ErrorReport _report({required ErrorSeverity severity}) {
  final occurredAt = DateTime.utc(2026, 8, 30, 12);
  return ErrorReport(
    eventId: 'warning-id',
    source: ErrorSource.platformDispatcher,
    severity: severity,
    firstOccurredAt: occurredAt,
    lastOccurredAt: occurredAt,
    errorType: 'StateError',
    playerErrorCode: null,
    message: 'warning evidence',
    rawStackTrace: 'warning stack',
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
    final directory = await Directory.systemTemp.createTemp('error-log-sink-');
    return _LogFixture(directory, File('${directory.path}/error.log'));
  }

  /// Cleans the test-owned temporary directory after all pending writes finish.
  Future<void> dispose() => directory.delete(recursive: true);
}
