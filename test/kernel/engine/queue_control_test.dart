/// QueueControl 契约测试 — fake 引擎上验证队列语义 (v0.0.5 Phase 2).
///
/// QueueControl contract tests on FakeEngine: load/append/remove/jump/step
/// boundaries and mode mapping. MediaKitEngine 的纯逻辑 (URI 反解) 单独覆盖.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/media_kit_engine.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  group('openPlaylist', () {
    test('装载队列 — 镜像更新 + OpenSuccess + state idle', () async {
      final result = await engine.openPlaylist([
        'a.mp4',
        'b.mp4',
        'c.mp4',
      ], startIndex: 1);

      expect(result, isA<OpenSuccess>());
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(engine.queueIndex.value, 1);
      expect(engine.state.value, MediaState.idle);
      expect(engine.hasMedia, isTrue);
    });

    test('空列表 — OpenError 且不改变镜像', () async {
      engine.queuePaths.value = const ['keep.mp4'];

      final result = await engine.openPlaylist(const []);

      expect(result, isA<OpenError>());
      expect(engine.queuePaths.value, ['keep.mp4']);
    });

    test('startIndex 越界 — clamp 到合法范围', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 99);

      expect(engine.queueIndex.value, 1); // clamp 到 length-1
    });
  });

  group('appendToQueue', () {
    test('追加不打断当前播放 — index 不变', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      await engine.jumpTo(0);

      await engine.appendToQueue(['c.mp4']);

      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(engine.queueIndex.value, 0);
    });

    test('空列表追加 — no-op', () async {
      await engine.openPlaylist(['a.mp4']);

      await engine.appendToQueue(const []);

      expect(engine.queuePaths.value, ['a.mp4']);
    });
  });

  group('removeFromQueue', () {
    test('删除当前之前的条目 — index 前移', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4'], startIndex: 2);

      await engine.removeFromQueue(0);

      expect(engine.queuePaths.value, ['b.mp4', 'c.mp4']);
      expect(engine.queueIndex.value, 1); // 2-1
    });

    test('删除正在播放条目 — index 保持并 clamp', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4'], startIndex: 1);

      await engine.removeFromQueue(1);

      expect(engine.queuePaths.value, ['a.mp4', 'c.mp4']);
      // 被删处的新条目接管 (mpv 自动跳转语义, 乐观镜像 clamp)
      expect(engine.queueIndex.value, 1);
    });

    test('删除唯一条目 — 归一为空队列 index -1', () async {
      await engine.openPlaylist(['a.mp4']);

      await engine.removeFromQueue(0);

      expect(engine.queuePaths.value, isEmpty);
      expect(engine.queueIndex.value, -1);
    });

    test('越界移除 — no-op', () async {
      await engine.openPlaylist(['a.mp4']);

      await engine.removeFromQueue(5);

      expect(engine.queuePaths.value, ['a.mp4']);
      expect(engine.removedIndices, isEmpty);
    });
  });

  group('jumpTo', () {
    test('合法索引 — 跳转并播放', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);

      final ok = await engine.jumpTo(1);

      expect(ok, isTrue);
      expect(engine.queueIndex.value, 1);
      expect(engine.state.value, MediaState.playing);
    });

    test('越界索引 — 返回 false 且无副作用', () async {
      await engine.openPlaylist(['a.mp4']);

      expect(await engine.jumpTo(1), isFalse);
      expect(await engine.jumpTo(-1), isFalse);
      expect(engine.jumpedToIndices, isEmpty);
    });
  });

  group('nextInQueue / previousInQueue', () {
    test('正常步进', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4'], startIndex: 0);

      expect(engine.nextInQueue(), isTrue);
      expect(engine.queueIndex.value, 1);

      expect(engine.previousInQueue(), isTrue);
      expect(engine.queueIndex.value, 0);
    });

    test('末尾回绕 (loopAll)', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 1);
      await engine.setPlayMode(PlayMode.loopAll);

      expect(engine.nextInQueue(), isTrue);
      expect(engine.queueIndex.value, 0); // 回绕到开头
    });

    test('开头回绕 (loopAll)', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 0);

      expect(engine.previousInQueue(), isTrue);
      expect(engine.queueIndex.value, 1); // 回绕到末尾
    });

    test('loopSingle 下用户切曲仍回绕', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 1);
      await engine.setPlayMode(PlayMode.loopSingle);

      expect(engine.nextInQueue(), isTrue);
      expect(engine.queueIndex.value, 0);
    });

    test('未播放 (index -1) 步进 — 从头开始', () async {
      await engine.appendToQueue(['a.mp4', 'b.mp4']);
      expect(engine.queueIndex.value, -1);

      expect(engine.nextInQueue(), isTrue);
      expect(engine.queueIndex.value, 0);
    });

    test('空队列 — false', () {
      expect(engine.nextInQueue(), isFalse);
      expect(engine.previousInQueue(), isFalse);
    });
  });

  group('setPlayMode', () {
    test('模式写入引擎 notifier (单一数据源)', () async {
      await engine.setPlayMode(PlayMode.shuffle);

      expect(engine.playMode.value, PlayMode.shuffle);
      expect(engine.lastSetPlayMode, PlayMode.shuffle);
    });
  });

  group('MediaKitEngine URI 纯逻辑', () {
    test('path ↔ uri 往返对称 (Windows 本地路径)', () {
      // 通过 MediaKitEngine 静态纯逻辑验证 — 不实例化引擎 (无 libmpv).
      const path = r'D:\media\video_1.mp4';
      final uri = MediaKitEngine.mediaUriFromPath(path);

      expect(uri, 'file:///D:/media/video_1.mp4');
      expect(MediaKitEngine.pathFromMediaUri(uri), path);
    });

    test('URL 原样往返', () {
      const url = 'https://example.com/stream.mp4';

      expect(MediaKitEngine.mediaUriFromPath(url), url);
      expect(MediaKitEngine.pathFromMediaUri(url), url);
    });
  });
}
