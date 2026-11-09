// MpvKitEngine 队列 + 音量回声 headless 测试 — 真实 libmpv (vo=null/ao=null).
//
// 覆盖 mpv_kit_engine_queue.dart 的追加/批量移除/步进回绕/shuffle/模式映射
// 以及 volume 属性回声过滤 (setVolume 不被 mpv 回显往返覆写).
@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_kit_engine.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_property_mapper.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

import '../../helpers/bundled_libmpv.dart';
import '../../helpers/native_engine_helpers.dart';

void main() {
  late Directory tmp;
  late MpvKitEngine engine;

  /// 生成 [n] 个 WAV 并装载为队列 (起始 [start]).
  Future<List<String>> loadQueue(int n, {int start = 0}) async {
    final files = [
      for (var i = 0; i < n; i++) wavFile(tmp, 'q$i.wav', ms: 4000).path,
    ];
    expect(
      await engine.openPlaylist(files, startIndex: start),
      isA<OpenSuccess>(),
    );
    return files;
  }

  setUpAll(() {
    loadBundledLibmpvForTests();
    tmp = Directory.systemTemp.createTempSync('mpvkit_queue');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(
    () => engine = MpvKitEngine(
      playerOptions: const {'vo': 'null', 'ao': 'null'},
    ),
  );
  tearDown(() => engine.dispose());

  group('队列编辑', () {
    test('openPlaylist 空列表 → OpenError(pathEmpty), 不改镜像', () async {
      final result = await engine.openPlaylist(const <String>[]);
      expect(result, isA<OpenError>());
      expect(engine.queuePaths.value, isEmpty);
      expect(engine.lastError.value, isA<FileError>());
    });

    test('appendToQueue 追加到末尾, index 不变, revision 单发', () async {
      final files = await loadQueue(2);
      final extra = wavFile(tmp, 'extra.wav').path;
      final before = engine.queueRevision.value;

      await engine.appendToQueue([extra]);

      expect(engine.queuePaths.value, [...files, extra]);
      expect(engine.queueIndex.value, 0);
      expect(engine.queueRevision.value, before + 1);
    });

    test('removeFromQueueBatch 降序移除, 镜像与 mpv 收敛, revision 单发', () async {
      final files = await loadQueue(4, start: 3);
      final before = engine.queueRevision.value;

      await engine.removeFromQueueBatch({0, 2, 99}); // 99 越界被过滤

      expect(engine.queuePaths.value, [files[1], files[3]]);
      // 正在播放的条目 (原 index 3) 前移到 1.
      expect(engine.queueIndex.value, 1);
      expect(engine.queueRevision.value, before + 1);
      // 回流收敛后镜像与 mpv 原生 playlist 一致.
      await pumpEventQueue();
      expect([
        for (final e in engine.player.playlist.value) e.filename,
      ], engine.queuePaths.value);
    });

    test('removeFromQueue 越界为 no-op (不发 revision)', () async {
      await loadQueue(2);
      final before = engine.queueRevision.value;
      await engine.removeFromQueue(5);
      await engine.removeFromQueue(-1);
      expect(engine.queueRevision.value, before);
    });
  });

  group('步进与模式', () {
    test('nextInQueue / previousInQueue 越界回绕', () async {
      final files = await loadQueue(3, start: 2);
      expect(engine.nextInQueue(), isTrue);
      expect(engine.queueIndex.value, 0, reason: '末尾 next 回绕到 0');
      expect(engine.previousInQueue(), isTrue);
      expect(engine.queueIndex.value, files.length - 1, reason: '0 prev 回绕');
    });

    test('jumpTo 越界返回 false 且不动镜像', () async {
      await loadQueue(2);
      expect(await engine.jumpTo(7), isFalse);
      expect(await engine.jumpTo(-1), isFalse);
      expect(engine.queueIndex.value, 0);
    });

    test('shuffle 步进始终落在队列内且换曲', () async {
      await loadQueue(4);
      await engine.setPlayMode(PlayMode.shuffle);
      expect(engine.playMode.value, PlayMode.shuffle);
      for (var i = 0; i < 6; i++) {
        final current = engine.queueIndex.value;
        expect(engine.nextInQueue(), isTrue);
        final next = engine.queueIndex.value;
        expect(next, inInclusiveRange(0, 3));
        expect(next, isNot(current), reason: '多曲队列 shuffle 不原地重播');
      }
    });

    test('setPlayMode 映射 mpv loop 属性', () async {
      await loadQueue(2);
      final mpv = engine.player.mpv;
      await engine.setPlayMode(PlayMode.loopSingle);
      expect(mpv.getPropertyString('loop-file'), isNot('no'));
      await engine.setPlayMode(PlayMode.loopAll);
      expect(mpv.getPropertyString('loop-playlist'), isNot('no'));
      await engine.setPlayMode(PlayMode.shuffle);
      expect(mpv.getPropertyString('loop-playlist'), 'no');
      expect(mpv.getPropertyString('loop-file'), 'no');
    });
  });

  group('音量回声过滤', () {
    test('setVolume 值经 mpv 回显后不漂移, 且只通知一次', () async {
      var notifications = 0;
      engine.volume.addListener(() => notifications++);

      // 取一个立方根往返必有浮点误差的值.
      const target = 0.37;
      engine.setVolume(target);
      // 等 mpv volume 属性回显到达 (异步事件).
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(engine.volume.value, target, reason: '回显不得覆写权威值');
      expect(notifications, 1, reason: '回显不得再触发一次防抖落盘通知');
    });

    test('外部直写 mpv volume 仍回写 engine.volume (非回声)', () async {
      engine.player.setVolume(50); // 绕过引擎的外部来源
      await untilValue(
        engine.volume,
        (v) => (v - MpvPropertyMapper.mapVolumeFromMpv(50)).abs() < 1e-9,
      );
    });
  });

  test('打开已存在文件失败类别不误报 fileNotFound (异步存在性探测)', () async {
    // 存在但内容不是媒体 → mpv unknownFormat, 不得被异步探测误判为不存在.
    final junk = File('${tmp.path}${Platform.pathSeparator}junk.wav')
      ..writeAsBytesSync(List<int>.filled(64, 7));
    await engine.openPlaylist([junk.path]);
    engine.play();
    final e = await untilValue(engine.lastError, (e) => e != null);
    expect(e, isNotNull);
    expect(
      e is FileError && e.code == FileErrorCode.fileNotFound,
      isFalse,
      reason: '文件存在, 不应判为 fileNotFound',
    );
  });
}
