// MpvKitEngine headless 集成测试 — 真实 libmpv (vo=null/ao=null), 不创建
// 视频输出. 素材为 Dart 生成的静音 PCM WAV (精确可 seek, 无编解码依赖).
@Tags(['native'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_kit_engine.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

/// 写 [ms] 毫秒 8kHz 单声道 16-bit 静音 WAV.
File _wav(Directory dir, String name, {int ms = 600}) {
  const rate = 8000;
  final data = rate * ms ~/ 1000 * 2;
  final b = ByteData(44 + data);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  return File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(b.buffer.asUint8List());
}

/// 等待 notifier 满足条件 (先查当前值; 10s 超时).
Future<T> _until<T>(ValueListenable<T> n, bool Function(T) ok) {
  if (ok(n.value)) return Future.value(n.value);
  final c = Completer<T>();
  void l() {
    if (ok(n.value) && !c.isCompleted) c.complete(n.value);
  }

  n.addListener(l);
  return c.future
      .timeout(const Duration(seconds: 10))
      .whenComplete(() => n.removeListener(l));
}

void main() {
  late Directory tmp;
  late MpvKitEngine engine;

  setUpAll(() => tmp = Directory.systemTemp.createTempSync('mpvkit_engine'));
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(
    () => engine = MpvKitEngine(
      playerOptions: const {'vo': 'null', 'ao': 'null'},
    ),
  );
  tearDown(() => engine.dispose());

  test('open → play: 位置推进, 时长就绪', () async {
    final f = _wav(tmp, 'one.wav', ms: 1500);
    expect(await engine.open(f.path), isA<OpenSuccess>());
    engine.play();
    await _until(engine.duration, (d) => d > 1000);
    await _until(engine.position, (p) => p > 0);
    expect(engine.state.value, MediaState.playing);
  });

  test('文件名含 # 与 % 直传 mpv 可打开 (无 URI 编码层)', () async {
    final f = _wav(tmp, 'a#b 100%.wav');
    await engine.open(f.path);
    engine.play();
    await _until(engine.duration, (d) => d > 0);
  });

  test('openPlaylist: 镜像路径/起始 index, revision 单发', () async {
    final files = [for (var i = 0; i < 3; i++) _wav(tmp, 'q$i.wav').path];
    final before = engine.queueRevision.value;
    final r = await engine.openPlaylist(files, startIndex: 1);
    expect(r, isA<OpenSuccess>());
    expect(engine.queuePaths.value, files);
    expect(engine.queueIndex.value, 1);
    expect(engine.queueRevision.value, before + 1);
    // 回流收敛后镜像不变.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.queuePaths.value, files);
    expect(engine.queueIndex.value, 1);
  });

  test('loopAll: EOF 自动推进到下一条', () async {
    final files = [
      for (var i = 0; i < 2; i++) _wav(tmp, 'e$i.wav', ms: 300).path,
    ];
    await engine.setPlayMode(PlayMode.loopAll);
    await engine.openPlaylist(files);
    engine.play();
    await _until(engine.queueIndex, (i) => i == 1);
  });

  test('sortQueue / remove / jumpTo 保持镜像与播放身份一致', () async {
    final files = [
      for (var i = 0; i < 3; i++) _wav(tmp, 's$i.wav', ms: 3000).path,
    ];
    await engine.openPlaylist(files);
    engine.play();
    expect(await engine.jumpTo(2), isTrue);
    await engine.sortQueue([files[2], files[0], files[1]]);
    expect(engine.queuePaths.value, [files[2], files[0], files[1]]);
    expect(engine.queueIndex.value, 0);
    await engine.removeFromQueue(2);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.queuePaths.value, [files[2], files[0]]);
    expect(engine.queueIndex.value, 0);
  });

  test('打开不存在的文件 → lastError 为 FileError.fileNotFound', () async {
    await engine.open('${tmp.path}${Platform.pathSeparator}missing.wav');
    engine.play();
    final e = await _until(engine.lastError, (e) => e != null);
    expect(e, isA<FileError>());
  });

  test('stop 清空派生状态并回 idle', () async {
    await engine.open(_wav(tmp, 'stop.wav', ms: 2000).path);
    engine.play();
    await _until(engine.duration, (d) => d > 0);
    await engine.stop();
    expect(engine.state.value, MediaState.idle);
    expect(engine.hasMedia, isFalse);
    expect(engine.duration.value, 0);
  });
}
