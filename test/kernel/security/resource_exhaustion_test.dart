/// Resource exhaustion security tests.
///
/// Verifies that kernel components handle extreme resource pressure gracefully
/// without unbounded memory growth, file handle leaks, or denial-of-service.
///
/// Five attack surfaces:
///   1. Memory pressure — massive playlist, repeated engine opens
///   2. File handle exhaustion — rapid open/close cycles
///   3. Callback accumulation — ValueNotifier listener flood
///   4. Path validation performance — malicious path flood (no ReDoS)
///   5. Queue exhaustion — generation superseding, playlist bounds
///
/// Uses FakeEngine + Playlist directly — no mdk.dll FFI, headless CI safe.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/services/path_validator.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Memory Pressure
  // ────────────────────────────────────────────────────────────────────────────

  group('Memory pressure', () {
    test('Playlist handles 100,000 items without error', () {
      final playlist = Playlist();
      const count = 100000;

      // 添加 100k 条目 — 验证不抛异常、长度正确
      for (var i = 0; i < count; i++) {
        playlist.add('C:\\media\\video_$i.mp4');
      }

      expect(playlist.length, count);
      expect(playlist.currentIndex, 0);
      expect(playlist.current?.path, 'C:\\media\\video_0.mp4');

      // 导航到末尾 — 确保 peekNext 不越界
      playlist.currentIndex = count - 1;
      expect(playlist.peekNext(), 0); // loopAll 回绕

      // 删除操作在大列表上不崩溃
      playlist.removeAt(count - 1);
      expect(playlist.length, count - 1);
    });

    test('Playlist.addAll with 100,000 items completes', () {
      final playlist = Playlist();
      final paths = List.generate(100000, (i) => 'C:\\media\\bulk_$i.mp4');

      playlist.addAll(paths);

      expect(playlist.length, 100000);
    });

    test('FakeEngine handles repeated open without close', () async {
      // 模拟"打开 1000 个文件但从不关闭" — 引擎应只保留最后一个
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 5000);

      for (var i = 0; i < 1000; i++) {
        final result = await engine.open('C:\\media\\leak_$i.mp4');
        // 每次 open 成功（FakeEngine 简单替换内部状态）
        expect(result, isA<OpenSuccess>());
      }

      // 引擎内部状态只保留最后一个 — 无累积
      expect(engine.openCallCount, 1000);
      expect(engine.openPaths.length, 1000); // 路径记录用于测试
      expect(engine.duration.value, 5000);

      engine.dispose();
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 2. File Handle Exhaustion
  // ────────────────────────────────────────────────────────────────────────────

  group('File handle exhaustion', () {
    test('Rapid open/close 10,000 cycles — no accumulation', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 1000);

      for (var i = 0; i < 10000; i++) {
        await engine.open('C:\\media\\rapid_$i.mp4');
        // 模拟 close: stop 重置状态（FakeEngine 没有 close，stop 最接近）
        await engine.stop();
      }

      // 所有 open 都成功，引擎状态干净
      expect(engine.openCallCount, 10000);
      expect(engine.stopCallCount, 10000);
      expect(engine.state.value, MediaState.idle);
      expect(engine.position.value, 0);

      engine.dispose();
    });

    test('Dispose during rapid open — no crash', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 500);

      // 开始若干次 open，中途 dispose
      for (var i = 0; i < 100; i++) {
        await engine.open('C:\\media\\dispose_$i.mp4');
        if (i == 50) {
          engine.dispose();
        }
      }

      // dispose 后 open 返回 OpenSuperseded — 不崩溃
      final result = await engine.open('C:\\media\\after_dispose.mp4');
      expect(result, isA<OpenSuperseded>());
    });

    test('Double dispose — idempotent, no crash', () async {
      final engine = FakeEngine();

      engine.dispose();
      engine.dispose(); // 第二次 dispose 安全

      // dispose 后操作安全 no-op
      engine.play();
      engine.pause();
      await engine.stop();
      expect(engine.state.value, MediaState.idle);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 3. Callback Accumulation
  // ────────────────────────────────────────────────────────────────────────────

  group('Callback accumulation', () {
    test('Register 1000 listeners on ValueNotifier — notify works', () {
      final notifier = ValueNotifier<int>(0);
      var callCount = 0;

      // 注册 1000 个监听器
      for (var i = 0; i < 1000; i++) {
        notifier.addListener(() {
          callCount++;
        });
      }

      notifier.value = 1;
      expect(callCount, 1000);

      notifier.value = 2;
      expect(callCount, 2000);

      notifier.dispose();
    });

    test('ValueNotifier dispose prevents further notifications', () {
      final notifier = ValueNotifier<int>(0);

      // 添加监听器后 dispose — 确认 dispose 后不可用
      notifier.addListener(() {});
      notifier.dispose();

      // dispose 后修改 value — Dart 的 ValueNotifier 在 dispose 后
      // 设置 value 会抛 FlutterError（"used after being disposed"）
      expect(() => notifier.value = 1, throwsFlutterError);
    });

    test('FakeEngine ValueNotifiers survive listener flood', () async {
      final engine = FakeEngine();
      var stateChanges = 0;
      var positionChanges = 0;
      var volumeChanges = 0;

      // 先加载媒体 — 空置态 (hasMedia=false) play 会被 hasMedia guard 幂等
      // 忽略. open 在监听器注册前完成, state 通知计数只含 play 的 1 次.
      await engine.open('/test.mp4');

      // 每个 ValueNotifier 注册 200 个监听器
      for (var i = 0; i < 200; i++) {
        engine.state.addListener(() => stateChanges++);
        engine.position.addListener(() => positionChanges++);
        engine.volume.addListener(() => volumeChanges++);
      }

      engine.play(); // idle→playing = 1 次通知 × 200 监听器
      engine.setVolume(0.5);
      engine.position.value = 5000;

      expect(stateChanges, 200);
      expect(volumeChanges, 200);
      expect(positionChanges, 200);

      engine.dispose();
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 4. Path Validation Performance (No ReDoS)
  // ────────────────────────────────────────────────────────────────────────────

  group('Path validation performance', () {
    test('Validate 10,000 malicious paths — completes under 1 second', () {
      // 各类恶意路径构造 — 触发所有验证分支
      final maliciousPaths = [
        // 路径遍历
        '../../../etc/passwd',
        '..\\..\\..\\Windows\\System32\\config\\SAM',
        // Null byte 注入
        'video.mp4\x00evil.exe',
        'safe.mp4\x00\x00\x00../../etc/shadow',
        // UNC 路径
        '\\\\attacker.com\\share\\payload.exe',
        '\\\\192.168.1.1\\c\$\\Windows\\cmd.exe',
        // Home 目录展开
        '~/../../etc/passwd',
        '~/.ssh/id_rsa',
        // 控制字符
        'file\x01.mp4',
        'file\x1f.mp4',
        'path\x0d\x0a.mp4',
        // 不支持的扩展名
        'payload.exe',
        'script.bat',
        'malware.scr',
        'hack.com',
        // 空路径
        '',
        '   ',
        // 无效 URL
        'http://',
        'https://',
        'http://:8080/path',
        // 超长路径
        'C:\\${'a' * 10000}.mp4',
        // 混合攻击
        '../../../etc/passwd.mp4\x00.exe',
        '~/.ssh/key.mp4\x0a../../etc/shadow',
      ];

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        // 循环遍历所有恶意路径
        final path = maliciousPaths[i % maliciousPaths.length];
        PathValidator.validate(path);
      }

      stopwatch.stop();

      // 10k 次校验应在 1 秒内完成 — 验证无 ReDoS
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Validate 10,000 valid paths — baseline performance', () {
      final validPaths = [
        'C:\\media\\video.mp4',
        '/home/user/movie.mkv',
        'D:\\Music\\song.mp3',
        'relative/path/file.avi',
        'https://example.com/stream.mp4',
        'rtsp://camera.local/live',
      ];

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        final path = validPaths[i % validPaths.length];
        PathValidator.validate(path);
      }

      stopwatch.stop();

      // 有效路径同样在 1 秒内完成
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('filterValid with 10,000 mixed paths — bounded output', () {
      final paths = List.generate(10000, (i) {
        if (i % 3 == 0) return 'C:\\media\\video_$i.mp4';
        if (i % 3 == 1) return '../../../etc/passwd_$i';
        return 'malware_$i.exe';
      });

      final stopwatch = Stopwatch()..start();
      final valid = PathValidator.filterValid(paths);
      stopwatch.stop();

      // 只有 i%3==0 的路径通过 → 约 3334 条
      expect(valid.length, closeTo(3334, 1));
      expect(valid.every((p) => p.endsWith('.mp4')), isTrue);

      // 完成时间合理
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Worst-case path length — no exponential blowup', () {
      // 构造超长恶意路径：100KB 的 "../" 重复
      final traversal = '../' * 30000;
      final longPath = '$traversal${'a' * 100}.mp4';

      final stopwatch = Stopwatch()..start();
      final result = PathValidator.validate(longPath);
      stopwatch.stop();

      expect(result, isNotNull); // 应被拒绝
      // 超长遍历路径应在 100ms 内处理完
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('URL validation — authority check performance', () {
      // 测试大量无效 URL — 验证 Uri.tryParse 不成为瓶颈
      final urls = [
        'http://',
        'https://',
        'http://:8080',
        'https://:443/path',
        'http://${'a' * 5000}',
        'https://${'x' * 10000}.com/stream',
      ];

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        PathValidator.validate(urls[i % urls.length]);
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 5. Queue Exhaustion
  // ────────────────────────────────────────────────────────────────────────────

  group('Queue exhaustion', () {
    test(
      'FakeEngine generation guard — superseded operations discarded',
      () async {
        final engine = FakeEngine();
        engine.configureMedia(durationMs: 1000);

        // 快速连续 open — 旧 generation 被丢弃
        final futures = <Future<OpenResult>>[];
        for (var i = 0; i < 100; i++) {
          futures.add(engine.open('C:\\media\\gen_$i.mp4'));
          // 短暂 yield 让 generation 推进
          await Future<void>.value();
        }

        final results = await Future.wait(futures);

        // 大部分旧请求被 superseded，只有最后一个成功
        final superseded = results.whereType<OpenSuperseded>().length;
        final success = results.whereType<OpenSuccess>().length;

        // 至少有一个成功（最后一次 open），其余被 superseded
        expect(success, greaterThanOrEqualTo(1));
        expect(superseded + success, 100);

        engine.dispose();
      },
    );

    test('Playlist operations on empty playlist — no crash', () {
      final playlist = Playlist();

      expect(playlist.length, 0);
      expect(playlist.isEmpty, isTrue);
      expect(playlist.current, isNull);
      expect(playlist.hasNext, isFalse);
      expect(playlist.hasPrevious, isFalse);
      expect(playlist.peekNext(), -1);
      expect(playlist.peekPrevious(), -1);

      // removeAt on empty — 安全
      expect(playlist.removeAt(0), isFalse);

      // clear on empty — 安全
      playlist.clear();
      expect(playlist.length, 0);
    });

    test('Playlist rapid add/remove — index stays consistent', () {
      final playlist = Playlist();

      // 添加 1000 项
      for (var i = 0; i < 1000; i++) {
        playlist.add('C:\\media\\item_$i.mp4');
      }
      expect(playlist.length, 1000);

      // 删除所有偶数索引
      for (var i = 999; i >= 0; i -= 2) {
        playlist.removeAt(i);
      }
      expect(playlist.length, 500);

      // currentIndex 自动调整 — 不越界
      expect(playlist.currentIndex, lessThan(playlist.length));
      expect(playlist.currentIndex, greaterThanOrEqualTo(0));
    });

    test('Playlist shuffle mode with massive list — peekNext terminates', () {
      final playlist = Playlist();
      playlist.mode = PlayMode.shuffle;

      for (var i = 0; i < 10000; i++) {
        playlist.add('C:\\media\\shuffle_$i.mp4');
      }
      playlist.currentIndex = 5000;

      // shuffle 的 do-while 循环在 >1 项时必须终止
      final next = playlist.peekNext();
      expect(next, isNot(-1));
      expect(next, isNot(5000)); // shuffle 不返回自身
      expect(next, inInclusiveRange(0, 9999));
    });
  });
}
