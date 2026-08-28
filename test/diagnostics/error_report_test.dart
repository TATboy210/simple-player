/// Behavioral tests for the immutable Phase 1 diagnostic report contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';

void main() {
  group('ErrorReport', () {
    test(
      'copyWith replaces occurrence metadata without changing identity data',
      () {
        // Arrange
        final firstOccurredAt = DateTime.utc(2026, 8, 28, 12);
        final report = ErrorReport(
          eventId: 'event-1',
          source: ErrorSource.platformDispatcher,
          severity: ErrorSeverity.error,
          firstOccurredAt: firstOccurredAt,
          lastOccurredAt: firstOccurredAt,
          errorType: 'StateError',
          message: 'decoder callback failed',
          rawStackTrace: 'package:simple_player_flutter/test.dart:10',
          mediaPath: r'D:\media\demo.mp4',
          occurrenceCount: 1,
        );
        final later = firstOccurredAt.add(const Duration(seconds: 1));

        // Act
        final replacement = report.copyWith(
          occurrenceCount: 2,
          lastOccurredAt: later,
        );

        // Assert
        expect(replacement, isNot(same(report)));
        expect(replacement.eventId, report.eventId);
        expect(replacement.firstOccurredAt, report.firstOccurredAt);
        expect(replacement.source, report.source);
        expect(replacement.rawStackTrace, report.rawStackTrace);
        expect(replacement.mediaPath, report.mediaPath);
        expect(replacement.occurrenceCount, 2);
        expect(replacement.lastOccurredAt, later);
      },
    );
  });
}
