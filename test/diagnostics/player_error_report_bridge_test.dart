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
        final fixture = _BridgeFixture();
        addTearDown(fixture.dispose);

        // Act
        final opened = await fixture.controller.openAndPlay(
          r'C:\Users\alice\bad.txt',
        );
        fixture.reporter.flushPresentation();

        // Assert
        expect(opened, isFalse);
        expect(fixture.reporter.queuedReports, hasLength(1));
        final report = fixture.reporter.queuedReports.single;
        expect(report.source, ErrorSource.playerEngine);
        expect(report.message, isNot(contains(r'C:\Users\alice')));
        expect(report.mediaPath, isNot(contains(r'C:\Users\alice')));
        expect(fixture.reporter.presentation.value.current, same(report));
      },
    );

    test(
      'suppresses the identical OpenError after lastError already forwarded it',
      () async {
        // Arrange
        final fixture = _BridgeFixture();
        addTearDown(fixture.dispose);
        fixture.engine.failNextOpenWith = 'open failed';

        // Act
        final opened = await fixture.controller.openAndPlay(
          'C:/Videos/broken.mp4',
        );

        // Assert
        expect(opened, isFalse);
        expect(fixture.reporter.queuedReports, hasLength(1));
        expect(fixture.reporter.queuedReports.single.message, 'open failed');
      },
    );

    test(
      'forwards a later asynchronous notifier error with current media path',
      () async {
        // Arrange
        final fixture = _BridgeFixture();
        addTearDown(fixture.dispose);
        await fixture.controller.openAndPlay('C:/Videos/loaded.mp4');

        // Act
        fixture.engine.simulateError('asynchronous failure');

        // Assert
        expect(fixture.reporter.queuedReports, hasLength(1));
        final report = fixture.reporter.queuedReports.single;
        expect(report.message, 'asynchronous failure');
        expect(report.mediaPath, 'loaded.mp4');
      },
    );

    test('forwards a same-message distinct error instance independently', () {
      // Arrange
      final fixture = _BridgeFixture();
      addTearDown(fixture.dispose);
      final first = UnknownError('same message');
      final second = UnknownError('same message');

      // Act
      fixture.engine.lastError.value = first;
      fixture.bridge.reportControllerError(second);

      // Assert
      expect(fixture.reporter.queuedReports.single.occurrenceCount, 2);
    });

    test('detaches the listener and allows repeated disposal', () {
      // Arrange
      final fixture = _BridgeFixture();
      fixture.bridge.dispose();

      // Act
      fixture.engine.simulateError('after disposal');
      fixture.bridge.dispose();

      // Assert
      expect(fixture.reporter.queuedReports, isEmpty);
      fixture.controller.dispose();
      fixture.engine.dispose();
    });
  });
}

/// Groups the production bridge collaborators into a small test fixture.
final class _BridgeFixture {
  _BridgeFixture() : engine = FakeEngine(), reporter = _reporter() {
    bridge = PlayerErrorReportBridge(
      engine: engine,
      reporter: reporter,
      currentMediaPath: () => controller.currentPath.value,
    );
    controller = PlaybackController(
      engine: engine,
      onError: bridge.reportControllerError,
    );
  }

  final FakeEngine engine;
  final ErrorReporterImpl reporter;
  late final PlayerErrorReportBridge bridge;
  late final PlaybackController controller;

  /// Releases objects in the same dependency order as the service container.
  void dispose() {
    bridge.dispose();
    controller.dispose();
    engine.dispose();
  }
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
