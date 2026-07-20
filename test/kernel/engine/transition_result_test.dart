import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/transition_result.dart';

void main() {
  group('TransitionResult', () {
    test('has three values: ok, illegal, staleGeneration', () {
      expect(TransitionResult.values, hasLength(3));
      expect(TransitionResult.values, contains(TransitionResult.ok));
      expect(TransitionResult.values, contains(TransitionResult.illegal));
      expect(TransitionResult.values, contains(TransitionResult.staleGeneration));
    });

    test('ok is the first value (index 0)', () {
      expect(TransitionResult.ok.index, 0);
    });

    test('illegal is the second value (index 1)', () {
      expect(TransitionResult.illegal.index, 1);
    });

    test('staleGeneration is the third value (index 2)', () {
      expect(TransitionResult.staleGeneration.index, 2);
    });
  });
}
