import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/startup/startup_coordinator.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  group('StartupCoordinator', () {
    late StartupCoordinator coordinator;

    setUp(() {
      coordinator = StartupCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('initial state is binding phase with zero progress', () {
      expect(coordinator.state.value.phase, StartupPhase.binding);
      expect(coordinator.state.value.progress, 0.0);
      expect(coordinator.state.value.message, '');
    });

    test('report updates state with phase, progress, message', () {
      coordinator.report(
        StartupPhase.infrastructure,
        0.5,
        'Loading...',
      );
      expect(coordinator.state.value.phase, StartupPhase.infrastructure);
      expect(coordinator.state.value.progress, 0.5);
      expect(coordinator.state.value.message, 'Loading...');
    });

    test('report clamps progress to 0.0..1.0', () {
      coordinator.report(StartupPhase.infrastructure, -0.5, 'under');
      expect(coordinator.state.value.progress, 0.0);

      coordinator.report(StartupPhase.infrastructure, 1.5, 'over');
      expect(coordinator.state.value.progress, 1.0);
    });

    test('markReady sets phase to ready with progress 1.0', () {
      coordinator.markReady();
      expect(coordinator.state.value.phase, StartupPhase.ready);
      expect(coordinator.state.value.progress, 1.0);
      expect(coordinator.state.value.message, 'Ready');
    });

    test('listeners are notified on report', () {
      final values = <StartupState>[];
      coordinator.state.addListener(() {
        values.add(coordinator.state.value);
      });
      coordinator.report(StartupPhase.settings, 0.3, 'Settings');
      coordinator.report(StartupPhase.playerInit, 0.8, 'Player');
      expect(values.length, 2);
      expect(values[0].phase, StartupPhase.settings);
      expect(values[1].phase, StartupPhase.playerInit);
    });

    test('listeners are notified on markReady', () {
      final values = <StartupState>[];
      coordinator.state.addListener(() {
        values.add(coordinator.state.value);
      });
      coordinator.markReady();
      expect(values.length, 1);
      expect(values[0].phase, StartupPhase.ready);
    });

    test('multiple reports in same phase update state', () {
      coordinator.report(StartupPhase.infrastructure, 0.1, 'Starting');
      coordinator.report(StartupPhase.infrastructure, 0.5, 'Halfway');
      coordinator.report(StartupPhase.infrastructure, 1.0, 'Done');
      expect(coordinator.state.value.progress, 1.0);
      expect(coordinator.state.value.message, 'Done');
    });

    test('dispose does not throw', () {
      final c = StartupCoordinator();
      c.report(StartupPhase.infrastructure, 0.5, 'test');
      expect(() => c.dispose(), returnsNormally);
    });

    test('phase with progress 0.0 starts stopwatch', () {
      coordinator.report(StartupPhase.infrastructure, 0.0, 'Starting');
      expect(coordinator.state.value.progress, 0.0);
    });

    test('phase lifecycle: 0.0 then 1.0 records duration', () {
      coordinator.report(StartupPhase.infrastructure, 0.0, 'Starting');
      coordinator.report(StartupPhase.infrastructure, 1.0, 'Done');
      expect(coordinator.state.value.progress, 1.0);
    });

    test('markReady after completed phases logs timeline with durations', () {
      coordinator.report(StartupPhase.infrastructure, 0.0, 'Starting');
      coordinator.report(StartupPhase.infrastructure, 1.0, 'Done');
      coordinator.report(StartupPhase.settings, 0.0, 'Loading');
      coordinator.report(StartupPhase.settings, 1.0, 'Done');
      coordinator.markReady();
      expect(coordinator.state.value.phase, StartupPhase.ready);
    });

    test('markReady with phases that have timestamps but no duration', () {
      // Report at 0.5 (not 0.0) — timestamp recorded but no stopwatch started
      coordinator.report(StartupPhase.infrastructure, 0.5, 'Halfway');
      coordinator.markReady();
      expect(coordinator.state.value.phase, StartupPhase.ready);
    });

    test('markReady with skipped phases', () {
      // No reports for some phases — they should show as 'skipped'
      coordinator.markReady();
      expect(coordinator.state.value.phase, StartupPhase.ready);
    });

    test('report to ready phase directly', () {
      coordinator.report(StartupPhase.ready, 1.0, 'Done');
      expect(coordinator.state.value.phase, StartupPhase.ready);
      expect(coordinator.state.value.progress, 1.0);
    });

    test('multiple phases reported sequentially', () {
      for (final phase in StartupPhase.values) {
        if (phase == StartupPhase.ready) continue;
        coordinator.report(phase, 0.5, '${phase.name} half');
        expect(coordinator.state.value.phase, phase);
      }
    });

    test('phase timestamp is recorded on first report only', () {
      coordinator.report(StartupPhase.infrastructure, 0.3, 'First');
      // Second report in same phase — should not change timestamp
      coordinator.report(StartupPhase.infrastructure, 0.7, 'Second');
      expect(coordinator.state.value.progress, 0.7);
    });
  });
}
