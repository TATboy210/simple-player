import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_prewarm.dart';

void main() {
  group('EnginePrewarm', () {
    setUp(() {
      EnginePrewarm.reset();
    });

    test('isPrewarmed is false initially', () {
      expect(EnginePrewarm.isPrewarmed, isFalse);
    });

    test('isPlayerCreated is false initially', () {
      expect(EnginePrewarm.isPlayerCreated, isFalse);
    });

    test('isCodecsReady is false initially', () {
      expect(EnginePrewarm.isCodecsReady, isFalse);
    });

    test('isGpuReady is false initially', () {
      expect(EnginePrewarm.isGpuReady, isFalse);
    });

    test('reset clears all flags', () {
      // reset is already called in setUp, verify all flags are false
      expect(EnginePrewarm.isPrewarmed, isFalse);
      expect(EnginePrewarm.isPlayerCreated, isFalse);
      expect(EnginePrewarm.isCodecsReady, isFalse);
      expect(EnginePrewarm.isGpuReady, isFalse);
    });

    test('reset is idempotent', () {
      EnginePrewarm.reset();
      EnginePrewarm.reset();
      expect(EnginePrewarm.isPrewarmed, isFalse);
    });
  });
}
