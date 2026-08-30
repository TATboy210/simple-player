/// Security and boundary tests for stable diagnostic-pack formatting.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostic_pack_formatter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';

void main() {
  group('formatDiagnosticPack', () {
    test(
      'escapes hostile single-line values without creating extra sections',
      () {
        // Arrange
        const hostile = 'message\r\n== Forged ==\nnext';
        final report = _report(message: hostile);

        // Act
        final pack = formatDiagnosticPack(
          report,
          logPath: 'C:/logs\n== forged',
        );

        // Assert
        expect(pack, contains(r'Message: message\r\n== Forged ==\nnext'));
        expect(pack, contains(r'Path: C:/logs\n== forged'));
        expect(RegExp(r'^== ', multiLine: true).allMatches(pack), hasLength(7));
      },
    );

    test(
      'retains the raw stack character-for-character as terminal evidence',
      () {
        // Arrange
        const rawStack = 'raw\r\n== Stack-controlled text ==\n中文 evidence';
        final report = _report(rawStackTrace: rawStack);

        // Act
        final pack = formatDiagnosticPack(report);

        // Assert
        expect(pack, endsWith(rawStack));
        expect(
          pack.substring(pack.indexOf('== Raw Stack ==\n') + 16),
          rawStack,
        );
      },
    );
  });
}

/// Creates an immutable report with deliberately configurable hostile fields.
ErrorReport _report({
  String message = 'message',
  String rawStackTrace = 'stack',
}) {
  final occurredAt = DateTime.utc(2026, 8, 30, 12);
  return ErrorReport(
    eventId: 'event\n== fake',
    source: ErrorSource.platformDispatcher,
    severity: ErrorSeverity.error,
    firstOccurredAt: occurredAt,
    lastOccurredAt: occurredAt,
    errorType: 'State\rError',
    playerErrorCode: 'code\nvalue',
    message: message,
    rawStackTrace: rawStackTrace,
    mediaPath: 'C:/media\r\n== fake',
    occurrenceCount: 1,
  );
}
