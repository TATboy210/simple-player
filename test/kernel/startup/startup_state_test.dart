import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/startup/startup_state.dart';

void main() {
  group('StartupState', () {
    test('initial has default values', () {
      const state = StartupState.initial;
      expect(state.phase, StartupPhase.binding);
      expect(state.progress, 0.0);
      expect(state.message, '');
    });

    test('isReady is true only when phase is ready', () {
      expect(const StartupState().isReady, false);
      expect(
        const StartupState(phase: StartupPhase.ready).isReady,
        true,
      );
      expect(
        const StartupState(phase: StartupPhase.infrastructure).isReady,
        false,
      );
    });

    test('copyWith replaces specified fields', () {
      const original = StartupState(
        phase: StartupPhase.binding,
        progress: 0.0,
        message: 'init',
      );
      final updated = original.copyWith(
        phase: StartupPhase.infrastructure,
        progress: 0.5,
      );
      expect(updated.phase, StartupPhase.infrastructure);
      expect(updated.progress, 0.5);
      expect(updated.message, 'init'); // unchanged
    });

    test('copyWith with no arguments returns equivalent state', () {
      const original = StartupState(
        phase: StartupPhase.settings,
        progress: 0.7,
        message: 'loading',
      );
      final copy = original.copyWith();
      expect(copy, original);
    });

    test('equality compares all fields', () {
      const a = StartupState(
        phase: StartupPhase.playerInit,
        progress: 0.9,
        message: 'almost',
      );
      const b = StartupState(
        phase: StartupPhase.playerInit,
        progress: 0.9,
        message: 'almost',
      );
      const c = StartupState(
        phase: StartupPhase.playerInit,
        progress: 0.9,
        message: 'different',
      );
      expect(a, b);
      expect(a == c, false);
    });

    test('hashCode is consistent for equal states', () {
      const a = StartupState(
        phase: StartupPhase.ready,
        progress: 1.0,
        message: 'done',
      );
      const b = StartupState(
        phase: StartupPhase.ready,
        progress: 1.0,
        message: 'done',
      );
      expect(a.hashCode, b.hashCode);
    });

    test('identical returns true for same instance', () {
      const state = StartupState();
      expect(state == state, true);
    });
  });
}
