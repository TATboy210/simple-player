import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/player_error_report_bridge.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';

import '../helpers/fake_engine.dart';

void main() {
  group('PlayerErrorReportBridge', () {
    test(
      'forwards a controller validation failure as one sanitized report',
      () async {
        // Arrange
        final engine = FakeEngine();
        final reporter = _reporter();
        final bridge = PlayerErrorReportBridge(
          engine: engine,
          reporter: reporter,
          currentMediaPath: () => r'C:\Users\alice\Videos\active.mp4',
        );
        final controller = PlaybackController(
          engine: engine,
          onError: bridge.reportControllerError,
        );
        addTearDown(() {
          controller.dispose();
          bridge.dispose();
          engine.dispose();
        });

        // Act
        final opened = await controller.openAndPlay(r'C:\Users\alice\bad.txt');
        reporter.flushPresentation();

        // Assert
        expect(opened, isFalse);
        expect(reporter.queuedReports, hasLength(1));
        final report = reporter.queuedReports.single;
        expect(report.source, ErrorSource.playerEngine);
        expect(report.message, isNot(contains(r'C:\Users\alice')));
        expect(report.mediaPath, isNot(contains(r'C:\Users\alice')));
        expect(reporter.presentation.value.current, same(report));
      },
    );
  });
}

/// Builds a deterministic reporter for bridge behavior tests.
ErrorReporterImpl _reporter() {
  var sequence = 0;
  return ErrorReporterImpl.forTesting(
    clock: FakeClock(DateTime.utc(2026, 8, 28)),
    eventIdGenerator: () => 'bridge-${++sequence}',
    currentMediaPath: () => null,
  );
}
