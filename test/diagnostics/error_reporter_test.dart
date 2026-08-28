/// Behavioral tests for the full Phase 1 error-reporting contract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostic_redactor.dart';
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

  group('ErrorReporterImpl diagnostic redaction', () {
    test(
      'redacts every local path family before queue effect and presentation',
      () {
        const cases = <({String path, String secret, String basename})>[
          (
            path: r'C:\Users\alice\Videos\clip.mp4',
            secret: r'C:\Users\alice\Videos',
            basename: 'clip.mp4',
          ),
          (
            path: r'\\server\private-share\clip.mp4',
            secret: r'\\server\private-share',
            basename: 'clip.mp4',
          ),
          (
            path: '/home/alice/Videos/clip.mp4',
            secret: '/home/alice/Videos',
            basename: 'clip.mp4',
          ),
          (
            path: 'file:///C:/Users/alice/Videos/clip%20one.mp4',
            secret: 'C:/Users/alice/Videos',
            basename: 'clip one.mp4',
          ),
          (
            path:
                r'C:\Users\alice\Private Videos (Archive)\[2026]\incident.mp4',
            secret: r'C:\Users\alice\Private Videos (Archive)\[2026]',
            basename: 'incident.mp4',
          ),
          (
            path: '/home/alice/Private Videos (Archive)/[2026]/incident.mp4',
            secret: '/home/alice/Private Videos (Archive)/[2026]',
            basename: 'incident.mp4',
          ),
        ];

        for (final pathCase in cases) {
          // Arrange
          final effects = <ErrorReport>[];
          final reporter = _reporter(
            effects: [(report, _) => effects.add(report)],
          );
          final stack = StackTrace.fromString(
            'at Player.open (${pathCase.path}:7:8)\n'
            'package:simple_player_flutter/player.dart:2',
          );
          final error = UnknownError(
            'Unable to open ${pathCase.path}',
            null,
            ErrorContext(path: pathCase.path, callbackStackTrace: stack),
          );

          // Act
          reporter.reportPlayerError(error);
          reporter.flushPresentation();

          // Assert
          final report = reporter.queuedReports.single;
          final observed = <ErrorReport>[
            report,
            effects.single,
            reporter.presentation.value.current!,
          ];
          for (final snapshot in observed) {
            expect(snapshot.mediaPath, isNot(contains(pathCase.secret)));
            expect(snapshot.message, isNot(contains(pathCase.secret)));
            expect(snapshot.rawStackTrace, isNot(contains(pathCase.secret)));
            expect(snapshot.mediaPath, contains(pathCase.basename));
            expect(snapshot.rawStackTrace, contains(':7:8'));
          }
        }
      },
    );

    test(
      'redacts quoted and unquoted whitespace paths without consuming diagnostics',
      () {
        // Arrange
        const windows =
            r'C:\Users\alice\Private Videos (Archive)\[2026]\incident.mp4';
        const posix =
            '/home/alice/Private Videos (Archive)/[2026]/incident.mp4';
        final cases = <({String input, String secret})>[
          (input: 'Unable to open "$windows":7:8 (retry)', secret: windows),
          (input: 'Unable to open $posix:7:8 [retry]', secret: posix),
        ];

        for (final pathCase in cases) {
          // Act
          final redacted = DiagnosticRedactor.redactDiagnosticText(
            pathCase.input,
          );

          // Assert
          expect(redacted, isNot(contains(pathCase.secret)));
          expect(redacted, contains('incident.mp4'));
          expect(redacted, contains(':7:8'));
          expect(redacted, contains('Unable to open'));
          expect(redacted, contains('retry'));
        }
      },
    );

    test('is idempotent and leaves package frames and network URLs intact', () {
      // Arrange
      const text =
          'package:simple_player_flutter/player.dart:2 http://example.test/a https://example.test/a rtsp://camera/live';

      // Act
      final once = DiagnosticRedactor.redactDiagnosticText(text);
      final twice = DiagnosticRedactor.redactDiagnosticText(once);

      // Assert
      expect(twice, once);
      expect(once, contains('package:simple_player_flutter/player.dart:2'));
      expect(once, contains('http://example.test/a'));
      expect(once, contains('https://example.test/a'));
      expect(once, contains('rtsp://camera/live'));
    });
  });

  group('ErrorReporterImpl queue policy', () {
    test(
      'does not merge a matching report after the wall clock rolls back',
      () {
        // Arrange
        final clock = FakeClock(DateTime.utc(2026, 8, 28, 12));
        final reporter = _reporter(clock: clock);
        final stack = _stack('rollback.dart');

        // Act
        reporter.reportPlatformSafely(StateError('same'), stack);
        clock.currentTime = clock.now().subtract(const Duration(minutes: 3));
        reporter.reportPlatformSafely(StateError('same'), stack);

        // Assert
        expect(reporter.queuedReports, hasLength(2));
        expect(reporter.queuedReports.first.occurrenceCount, 1);
        expect(reporter.queuedReports.last.occurrenceCount, 1);
        expect(
          reporter.queuedReports.first.eventId,
          isNot(reporter.queuedReports.last.eventId),
        );
      },
    );

    test('merges duplicate reports at zero and ten seconds but not above', () {
      // Arrange
      final clock = FakeClock(DateTime.utc(2026, 8, 28, 12));
      final reporter = _reporter(clock: clock);
      final stack = _stack('boundary.dart');

      // Act
      reporter.reportPlatformSafely(StateError('same'), stack);
      reporter.reportPlatformSafely(StateError('same'), stack);
      clock.currentTime = clock.now().add(const Duration(seconds: 10));
      reporter.reportPlatformSafely(StateError('same'), stack);
      clock.currentTime = clock.now().add(const Duration(seconds: 11));
      reporter.reportPlatformSafely(StateError('same'), stack);

      // Assert
      expect(reporter.queuedReports, hasLength(2));
      expect(reporter.queuedReports.first.occurrenceCount, 3);
      expect(reporter.queuedReports.last.occurrenceCount, 1);
    });
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
