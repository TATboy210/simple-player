import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_engine.dart';

void main() {
  group('MediaEngine new methods', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('setExternalSubtitle tracks call and stores path', () {
      engine.setExternalSubtitle('/path/to/sub.srt');
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, '/path/to/sub.srt');

      engine.setExternalSubtitle('/path/to/sub2.ass');
      expect(engine.setExternalSubtitleCallCount, 2);
      expect(engine.lastExternalSubtitlePath, '/path/to/sub2.ass');
    });

    test('setExternalSubtitle is no-op when disposed', () {
      final testEngine = FakeEngine();
      testEngine.dispose();
      testEngine.setExternalSubtitle('/path/to/sub.srt');
      expect(testEngine.setExternalSubtitleCallCount, 0);
    });

    test('setSubtitleDelay tracks call and stores delay', () {
      engine.setSubtitleDelay(500);
      expect(engine.setSubtitleDelayCallCount, 1);
      expect(engine.subtitleDelay, 500);

      engine.setSubtitleDelay(-200);
      expect(engine.setSubtitleDelayCallCount, 2);
      expect(engine.subtitleDelay, -200);
    });

    test('setSubtitleDelay is no-op when disposed', () {
      final testEngine = FakeEngine();
      testEngine.dispose();
      testEngine.setSubtitleDelay(500);
      expect(testEngine.setSubtitleDelayCallCount, 0);
    });

    test('subtitleDelay defaults to 0', () {
      expect(engine.subtitleDelay, 0);
    });
  });
}
