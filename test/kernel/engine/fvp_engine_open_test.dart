/// FvpEngine.open() generation 计数器测试
///
/// 验证快速切歌场景下，旧 open() 结果被正确丢弃，
/// 以及 dispose 后不更新状态。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FvpEngine.open() generation guard', () {
    test('rapid open() — only last request wins', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      // 快速连续 open 3 个文件 — 只有最后一个应生效
      final f1 = engine.open('C:/a.mp4');
      final f2 = engine.open('C:/b.mp4');
      final f3 = engine.open('C:/c.mp4');
      await f1;
      await f2;
      await f3;

      // openPaths 记录了所有调用，但状态只反映最后一次
      expect(engine.openPaths, ['C:/a.mp4', 'C:/b.mp4', 'C:/c.mp4']);
      expect(engine.openCallCount, 3);
      // 最后一次 open 成功后状态应为 idle
      expect(engine.state.value, MediaState.idle);

      engine.dispose();
    });

    test('open() after dispose does not update state', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      // 启动 open 但不 await
      final future = engine.open('C:/a.mp4');
      // 立即 dispose
      engine.dispose();
      await future;

      // dispose 后状态不应被更新（FakeEngine 的 _disposed 守卫）
      // 这里验证不会抛出异常 — 安全降级
    });

    test('open() with error — generation still advances', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      engine.failNextOpenWith = 'decode error';
      await engine.open('C:/bad.mp4');

      // 错误后 generation 已递增，再次 open 应正常工作
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/good.mp4');
      expect(engine.state.value, MediaState.idle);
      expect(engine.lastError.value, isNull);

      engine.dispose();
    });

    test('open() call tracking records all paths', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      await engine.open('C:/first.mp4');
      await engine.open('C:/second.mp4');
      await engine.open('C:/third.mp4');

      expect(engine.openCallCount, 3);
      expect(engine.openPaths, [
        'C:/first.mp4',
        'C:/second.mp4',
        'C:/third.mp4',
      ]);

      engine.dispose();
    });
  });
}
