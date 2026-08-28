/// Behavioral tests for the Phase 1 platform-error reporting tracer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';

void main() {
  group('ErrorReporterImpl platform path', () {
    test('captures, queues, effects, and flushes one platform report', () {
      // Arrange
      final occurredAt = DateTime.utc(2026, 8, 28, 12);
      final delivered = <(ErrorReport, ReportAcceptance)>[];
      final reporter = ErrorReporterImpl.forTesting(
        clock: FakeClock(occurredAt),
        eventIdGenerator: () => 'event-1',
        currentMediaPath: () => r'D:\media\demo.mp4',
        effects: [(report, acceptance) => delivered.add((report, acceptance))],
      );
      final stack = StackTrace.fromString(
        'package:simple_player_flutter/test.dart:10',
      );

      // Act
      reporter.reportPlatformSafely(
        StateError('decoder callback failed'),
        stack,
      );

      // Assert
      final queued = reporter.queuedReports.single;
      expect(queued.source, ErrorSource.platformDispatcher);
      expect(queued.severity, ErrorSeverity.error);
      expect(queued.eventId, 'event-1');
      expect(queued.firstOccurredAt, occurredAt);
      expect(queued.lastOccurredAt, occurredAt);
      expect(queued.rawStackTrace, stack.toString());
      expect(queued.mediaPath, r'D:\media\demo.mp4');
      expect(delivered, [(queued, ReportAcceptance.newReport)]);
      expect(reporter.presentation.value.current, isNull);
      expect(reporter.presentation.value.pendingCount, 1);

      reporter.flushPresentation();

      expect(reporter.presentation.value.current, same(queued));
      expect(reporter.presentation.value.pendingCount, 0);
    });
  });

  group('ErrorReporterImpl lifecycle', () {
    tearDown(ErrorReporterImpl.resetForTesting);

    test('isInitialized changes from false to true after idempotent init', () {
      // Arrange
      ErrorReporterImpl.resetForTesting();

      // Act and assert
      expect(ErrorReporterImpl.isInitialized, isFalse);
      ErrorReporterImpl.init();
      ErrorReporterImpl.init();
      expect(ErrorReporterImpl.isInitialized, isTrue);
      expect(ErrorReporterImpl.I, isA<ErrorReporterImpl>());
    });
  });
}
