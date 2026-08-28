/// Behavioral tests for the full Phase 1 error-reporting contract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

void main() {
  group('ErrorReporterImpl adapters', () {
    test('normalizes framework, bootstrap, platform, and player inputs', () {
      // Arrange
      final reporter = _reporter();
      final supplied = StackTrace.fromString(
        'package:simple_player_flutter/a.dart:1',
      );
      final player = PlaybackError(
        PlaybackErrorCode.textureFailed,
        'texture failure',
        null,
        ErrorContext(path: 'context.mp4', callbackStackTrace: supplied),
      );

      // Act
      reporter.reportFlutterSafely(
        FlutterErrorDetails(exception: StateError('ui'), stack: supplied),
      );
      reporter.reportBootstrapSafely(StateError('boot'), supplied);
      reporter.reportPlatformSafely(StateError('platform'), supplied);
      reporter.reportPlayerError(player, mediaPath: 'explicit.mp4');

      // Assert
      expect(reporter.queuedReports.map((report) => report.source), [
        ErrorSource.flutterFramework,
        ErrorSource.guardedZone,
        ErrorSource.platformDispatcher,
        ErrorSource.playerEngine,
      ]);
      final report = reporter.queuedReports.last;
      expect(report.severity, ErrorSeverity.fatal);
      expect(report.mediaPath, 'explicit.mp4');
      expect(report.rawStackTrace, supplied.toString());
      _expectCompleteReport(report);
    });

    test(
      'uses a bounded unavailable marker for a Flutter error without stack',
      () {
        // Arrange
        final reporter = _reporter();

        // Act and assert
        expect(
          () => reporter.reportFlutterSafely(
            FlutterErrorDetails(exception: StateError('missing stack')),
          ),
          returnsNormally,
        );
        final report = reporter.queuedReports.single;
        expect(
          report.rawStackTrace,
          ErrorReporterImpl.unavailableOriginalStackMarker,
        );
        expect(report.rawStackTrace, isNotEmpty);
        _expectCompleteReport(report);
      },
    );

    test(
      'snapshots PlayerError context values without retaining mutable context',
      () {
        // Arrange
        final contextualStack = StackTrace.fromString(
          'package:simple_player_flutter/player.dart:7',
        );
        final player = PlaybackError(
          PlaybackErrorCode.playFailed,
          'engine failed',
          null,
          ErrorContext(
            path: 'context.mp4',
            callbackStackTrace: contextualStack,
          ),
        );
        final reporter = _reporter();

        // Act
        reporter.reportPlayerError(player);
        player.context = ErrorContext(
          path: 'changed.mp4',
          callbackStackTrace: StackTrace.fromString('changed'),
        );

        // Assert
        final report = reporter.queuedReports.single;
        expect(report.rawStackTrace, contextualStack.toString());
        expect(report.mediaPath, 'context.mp4');
        _expectCompleteReport(report);
      },
    );

    test('uses the same marker when PlayerError has no contextual stack', () {
      // Arrange
      final player = PlaybackError(
        PlaybackErrorCode.playFailed,
        'engine failed',
      );
      final reporter = _reporter();

      // Act and assert
      expect(() => reporter.reportPlayerError(player), returnsNormally);
      final report = reporter.queuedReports.single;
      expect(
        report.rawStackTrace,
        ErrorReporterImpl.unavailableOriginalStackMarker,
      );
      _expectCompleteReport(report);
    });
  });

  group('ErrorReporterImpl queue policy', () {
    test(
      'evicts the sixth distinct head, dismisses FIFO head, and flushes idempotently',
      () {
        // Arrange
        final reporter = _reporter();
        final stack = _stack('policy.dart');

        // Act
        for (var index = 1; index <= 6; index += 1) {
          reporter.reportPlatformSafely(StateError('error-$index'), stack);
        }
        reporter.flushPresentation();
        reporter.flushPresentation();

        // Assert
        expect(reporter.queuedReports.map((report) => report.message), [
          'Bad state: error-2',
          'Bad state: error-3',
          'Bad state: error-4',
          'Bad state: error-5',
          'Bad state: error-6',
        ]);
        expect(
          reporter.presentation.value.current,
          same(reporter.queuedReports.first),
        );
        expect(reporter.presentation.value.pendingCount, 4);

        reporter.dismissCurrent();

        expect(
          reporter.presentation.value.current,
          same(reporter.queuedReports.first),
        );
        expect(reporter.queuedReports.first.message, 'Bad state: error-3');
      },
    );

    test(
      'merges matching inputs inside ten seconds and appends after the window',
      () {
        // Arrange
        final clock = FakeClock(DateTime.utc(2026, 8, 28));
        final reporter = _reporter(clock: clock);
        final stack = _stack('dedupe.dart');

        // Act
        reporter.reportPlatformSafely(StateError('same'), stack);
        clock.currentTime = clock.now().add(const Duration(seconds: 9));
        reporter.reportPlatformSafely(StateError('same'), stack);
        final merged = reporter.queuedReports.single;
        clock.currentTime = clock.now().add(const Duration(seconds: 11));
        reporter.reportPlatformSafely(StateError('same'), stack);

        // Assert
        expect(merged.occurrenceCount, 2);
        expect(reporter.queuedReports, hasLength(2));
        expect(reporter.queuedReports.first.eventId, merged.eventId);
      },
    );

    test(
      'keeps 100 and 1000 duplicate bursts bounded with accumulated counts',
      () {
        // Arrange
        final reporter = _reporter();
        final stack = _stack('burst.dart');

        // Act
        for (var index = 0; index < 100; index += 1) {
          reporter.reportPlatformSafely(StateError('storm'), stack);
        }

        // Assert
        expect(reporter.queuedReports, hasLength(1));
        expect(reporter.queuedReports.single.occurrenceCount, 100);

        // Act
        for (var index = 0; index < 900; index += 1) {
          reporter.reportPlatformSafely(StateError('storm'), stack);
        }

        // Assert
        expect(reporter.queuedReports, hasLength(1));
        expect(reporter.queuedReports.single.occurrenceCount, 1000);
      },
    );
  });

  group('ErrorReporterImpl fault isolation', () {
    test('contains malformed collaborator failures without throwing', () {
      // Arrange
      final lastResort = <Object>[];
      final reporter = ErrorReporterImpl.forTesting(
        clock: FakeClock(),
        eventIdGenerator: () => 'id',
        currentMediaPath: () => throw StateError('provider failed'),
        lastResortOutput: (error, _) => lastResort.add(error),
      );

      // Act and assert
      expect(
        () => reporter.reportPlatformSafely(
          _ThrowingMessage(),
          _stack('fault.dart'),
        ),
        returnsNormally,
      );
      expect(reporter.queuedReports, isEmpty);
      expect(lastResort, isNotEmpty);
    });

    test(
      'isolates listener and effect failures while suppressing reentrant intake',
      () {
        // Arrange
        final delivered = <(ErrorReport, ReportAcceptance)>[];
        final lastResort = <Object>[];
        late final ErrorReporterImpl reporter;
        reporter = ErrorReporterImpl.forTesting(
          clock: FakeClock(),
          eventIdGenerator: () => 'id',
          currentMediaPath: () => 'media.mp4',
          lastResortOutput: (error, _) => lastResort.add(error),
          effects: [
            (_, _) => throw StateError('effect failed'),
            (report, acceptance) => delivered.add((report, acceptance)),
            (_, _) => reporter.reportBootstrapSafely(
              StateError('reentrant'),
              _stack('reentrant.dart'),
            ),
          ],
        );
        final originalFlutterErrorHandler = FlutterError.onError;
        final listenerFailures = <FlutterErrorDetails>[];
        FlutterError.onError = listenerFailures.add;
        addTearDown(() => FlutterError.onError = originalFlutterErrorHandler);
        reporter.presentation.addListener(
          () => throw StateError('listener failed'),
        );

        // Act and assert
        expect(
          () => reporter.reportPlatformSafely(
            StateError('accepted'),
            _stack('fault.dart'),
          ),
          returnsNormally,
        );
        expect(reporter.queuedReports, hasLength(1));
        expect(delivered.single.$2, ReportAcceptance.newReport);
        expect(listenerFailures, hasLength(1));
        expect(lastResort, hasLength(2));
      },
    );

    test('notifies effects for new, merged, and post-window captures only', () {
      // Arrange
      final accepted = <ReportAcceptance>[];
      final clock = FakeClock(DateTime.utc(2026, 8, 28));
      final reporter = _reporter(
        clock: clock,
        effects: [(_, acceptance) => accepted.add(acceptance)],
      );
      final stack = _stack('effects.dart');

      // Act
      reporter.reportPlatformSafely(StateError('same'), stack);
      reporter.reportPlatformSafely(StateError('same'), stack);
      clock.currentTime = clock.now().add(const Duration(seconds: 11));
      reporter.reportPlatformSafely(StateError('same'), stack);
      for (var index = 0; index < 4; index += 1) {
        reporter.reportBootstrapSafely(
          StateError('new-$index'),
          _stack('new-$index.dart'),
        );
      }

      // Assert
      expect(accepted.take(3), [
        ReportAcceptance.newReport,
        ReportAcceptance.merged,
        ReportAcceptance.newReport,
      ]);
      expect(
        accepted.where((value) => value == ReportAcceptance.dropped),
        isEmpty,
      );
      expect(
        accepted.where(
          (value) => value == ReportAcceptance.reentrantSuppressed,
        ),
        isEmpty,
      );
    });
  });
}

/// Builds a deterministic reporter with local fake collaborators.
ErrorReporterImpl _reporter({
  Clock? clock,
  List<ErrorReportEffect> effects = const [],
}) {
  var sequence = 0;
  return ErrorReporterImpl.forTesting(
    clock: clock ?? FakeClock(DateTime.utc(2026, 8, 28)),
    eventIdGenerator: () => 'event-${++sequence}',
    currentMediaPath: () => 'provider.mp4',
    effects: effects,
  );
}

/// Creates a project-local stack line for stable fingerprint tests.
StackTrace _stack(String file) =>
    StackTrace.fromString('package:simple_player_flutter/$file:1');

/// Verifies the common immutable report shape required for every adapter.
void _expectCompleteReport(ErrorReport report) {
  expect(report.eventId, isNotEmpty);
  expect(report.firstOccurredAt, isNotNull);
  expect(report.lastOccurredAt, isNotNull);
  expect(report.errorType, isNotEmpty);
  expect(report.message, isNotEmpty);
  expect(report.rawStackTrace, isNotEmpty);
  expect(report.occurrenceCount, 1);
}

/// Simulates an untrusted diagnostic object with a failing string conversion.
final class _ThrowingMessage {
  @override
  String toString() => throw StateError('message failed');
}
