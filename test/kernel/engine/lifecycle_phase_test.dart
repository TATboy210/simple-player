import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/lifecycle_phase.dart';

void main() {
  group('LifecyclePhase', () {
    test('has three values: alive, disposing, disposed', () {
      expect(LifecyclePhase.values, hasLength(3));
      expect(LifecyclePhase.values, contains(LifecyclePhase.alive));
      expect(LifecyclePhase.values, contains(LifecyclePhase.disposing));
      expect(LifecyclePhase.values, contains(LifecyclePhase.disposed));
    });

    test('alive is the first value (index 0)', () {
      expect(LifecyclePhase.alive.index, 0);
    });

    test('disposing is the second value (index 1)', () {
      expect(LifecyclePhase.disposing.index, 1);
    });

    test('disposed is the third value (index 2)', () {
      expect(LifecyclePhase.disposed.index, 2);
    });
  });
}
