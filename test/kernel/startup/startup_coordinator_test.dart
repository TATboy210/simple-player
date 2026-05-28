import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/startup/startup_coordinator.dart';

void main() {
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
  });
}
