import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('Texture lifecycle', () {
    test('textureId is null initially', () {
      final engine = FakeEngine();
      expect(engine.textureId.value, isNull);
      engine.dispose();
    });

    test('textureId notifies listeners on change', () {
      final engine = FakeEngine();
      int notifyCount = 0;
      engine.textureId.addListener(() => notifyCount++);

      engine.textureId.value = 42;
      expect(notifyCount, 1);
      expect(engine.textureId.value, 42);

      engine.textureId.value = 99;
      expect(notifyCount, 2);
      expect(engine.textureId.value, 99);

      engine.dispose();
    });

    test('textureId can be set to null after being set', () {
      final engine = FakeEngine();
      engine.textureId.value = 1;
      expect(engine.textureId.value, 1);

      engine.textureId.value = null;
      expect(engine.textureId.value, isNull);
      engine.dispose();
    });

    test('dispose disposes textureId notifier', () {
      final engine = FakeEngine();
      engine.dispose();
      // After dispose, addListener should throw
      expect(() => engine.textureId.addListener(() {}), throwsFlutterError);
    });

    test('textureId is independent across engine instances', () {
      final engine1 = FakeEngine();
      final engine2 = FakeEngine();

      engine1.textureId.value = 1;
      engine2.textureId.value = 2;

      expect(engine1.textureId.value, 1);
      expect(engine2.textureId.value, 2);

      engine1.dispose();
      engine2.dispose();
    });
  });
}
