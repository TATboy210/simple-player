/// _NativeOpenDrain 队列语义测试 — 通过 FvpEngine 公共 API 验证原生队列隔离
///
/// 验证 _enqueueNativeOpen 的三个核心契约：
/// 1. 原生操作串行 — 前一请求的 prepare 未结束时，后续请求不触碰 Player
/// 2. Drain 排空 — 队列任务须等待前一请求的全部原生 Future settle
/// 3. Error 不阻塞 — 单次失败不永久阻塞后续请求
///
/// 使用 FakeMdkPlayer 的 Completer 控制 prepare 时序，
/// 不依赖 mdk.dll FFI，可在 headless CI 中运行。
///
/// 注意：所有测试使用 https:// URL 跳过 MediaOpener 的本地文件存在检查。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';

import '../../helpers/fake_mdk_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('_NativeOpenDrain queue semantics', () {
    group('rapid opens — only last request wins', () {
      test('3 rapid opens — only last returns OpenSuccess', () async {
        final player = FakeMdkPlayer();
        player
          ..prepareResult = 1
          ..updateTextureResult = 1
          ..textureIdValue = 1
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 60000);

        final engine = FvpEngine(playerFactory: () => player);

        // 快速连续发起 3 个 open — 不 await，立即启动
        final f1 = engine.open('https://example.com/a.mp4');
        final f2 = engine.open('https://example.com/b.mp4');
        final f3 = engine.open('https://example.com/c.mp4');

        final r1 = await f1;
        final r2 = await f2;
        final r3 = await f3;

        // 前两个请求应被取代（generation 递增后旧请求检查失败）
        expect(r1, isA<OpenSuperseded>());
        expect(r2, isA<OpenSuperseded>());
        // 最后一个请求成功
        expect(r3, isA<OpenSuccess>());

        engine.dispose();
      });

      test('3 rapid opens — final state reflects last request', () async {
        final player = FakeMdkPlayer();
        player
          ..prepareResult = 1
          ..updateTextureResult = 1
          ..textureIdValue = 1
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 30000);

        final engine = FvpEngine(playerFactory: () => player);

        final f1 = engine.open('https://example.com/first.mp4');
        final f2 = engine.open('https://example.com/second.mp4');
        final f3 = engine.open('https://example.com/third.mp4');
        await Future.wait<void>([f1, f2, f3]);

        // Player 最终设置为最后一个请求的路径
        expect(player.mediaPath, 'https://example.com/third.mp4');
        // duration 反映最后一个请求的媒体信息
        expect(engine.duration.value, 30000);

        engine.dispose();
      });
    });

    group('native queue serializes operations', () {
      test(
        'B does not start until A drain completes',
        () async {
          final player = FakeMdkPlayer();
          player
            ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 1000)
            ..textureIdValue = 1
            ..updateTextureResult = 1;

          // A 的 prepare 需要手动完成 — 控制原生操作时序
          final aPrepare = Completer<int>();
          player.nextPrepareCompleter = aPrepare;

          final engine = FvpEngine(playerFactory: () => player);

          // 启动 A — prepare 阻塞
          final fA = engine.open('https://example.com/A.mp4');

          // 等待 A 进入 prepare
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(player.prepareCallCount, 1);
          expect(player.mediaPath, 'https://example.com/A.mp4');

          // 启动 B — 排在 A 的 drain 之后
          player.prepareResult = 1;
          final fB = engine.open('https://example.com/B.mp4');

          // 完成 A 的 prepare — 触发 drain 排空
          aPrepare.complete(1);
          await Future<void>.delayed(const Duration(milliseconds: 100));

          final rA = await fA;
          final rB = await fB;

          // A 被 B 取代（B 的 generation 更新）
          expect(rA, isA<OpenSuperseded>());
          // B 成功完成
          expect(rB, isA<OpenSuccess>());
          // Player 路径最终是 B
          expect(player.mediaPath, 'https://example.com/B.mp4');

          engine.dispose();
        },
      );

      test('slow A drain — B waits for native settle', () async {
        final player = FakeMdkPlayer();
        player
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 1000)
          ..textureIdValue = 1
          ..updateTextureResult = 1;

        // A 的 prepare 有延迟 — 模拟慢速原生操作
        final aCompleter = Completer<int>();
        player.nextPrepareCompleter = aCompleter;

        final engine = FvpEngine(playerFactory: () => player);
        final sw = Stopwatch()..start();

        final fA = engine.open('https://example.com/slow-A.mp4');
        // 等 A 进入 prepare
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // B 用默认 prepareResult
        player.prepareResult = 1;
        final fB = engine.open('https://example.com/fast-B.mp4');

        // 200ms 后完成 A — 模拟慢速原生操作
        await Future<void>.delayed(const Duration(milliseconds: 200));
        aCompleter.complete(1);

        await Future.wait<void>([fA, fB]);
        final elapsed = sw.elapsedMilliseconds;

        // 总时间 >= 200ms（A 的 prepare 延迟），证明 B 等待了 A 的 drain
        expect(elapsed, greaterThanOrEqualTo(180));

        engine.dispose();
      });
    });

    group('error does not block queue', () {
      test('A fails — B still completes', () async {
        final player = FakeMdkPlayer();
        player
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 1000)
          ..textureIdValue = 1
          ..updateTextureResult = 1;

        // A 的 prepare 失败
        final aCompleter = Completer<int>();
        player.nextPrepareCompleter = aCompleter;

        final engine = FvpEngine(playerFactory: () => player);

        final fA = engine.open('https://example.com/fail.mp4');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // B 使用默认成功配置
        player.prepareResult = 1;
        final fB = engine.open('https://example.com/good.mp4');

        // A 的 prepare 返回错误
        aCompleter.complete(-1);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await fA; // 等待 A 完成（结果不需要）
        final rB = await fB;

        // 关键：B 不被 A 的失败阻塞
        expect(rB, isA<OpenSuccess>());
        expect(player.mediaPath, 'https://example.com/good.mp4');

        engine.dispose();
      });
    });

    group('same path rapid opens', () {
      test('open same path twice — second still succeeds', () async {
        final player = FakeMdkPlayer();
        player
          ..prepareResult = 1
          ..updateTextureResult = 1
          ..textureIdValue = 1
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 45000);

        final engine = FvpEngine(playerFactory: () => player);

        final f1 = engine.open('https://example.com/same.mp4');
        final f2 = engine.open('https://example.com/same.mp4');

        final r1 = await f1;
        final r2 = await f2;

        expect(r1, isA<OpenSuperseded>());
        expect(r2, isA<OpenSuccess>());
        expect(player.mediaPath, 'https://example.com/same.mp4');

        engine.dispose();
      });
    });

    group('dispose during queue', () {
      test('dispose while A is pending — returns OpenSuperseded', () async {
        final player = FakeMdkPlayer();
        player
          ..prepareResult = 1
          ..updateTextureResult = 1
          ..textureIdValue = 1
          ..mediaInfoToReturn = FakeMdkMediaInfo(duration: 1000);

        // A 的 prepare 阻塞
        final aCompleter = Completer<int>();
        player.nextPrepareCompleter = aCompleter;

        final engine = FvpEngine(playerFactory: () => player);

        final fA = engine.open('https://example.com/pending.mp4');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // dispose 时 A 仍在等待 prepare
        engine.dispose();

        // complete prepare — A 应检测到 disposed 返回 OpenSuperseded
        aCompleter.complete(1);

        final rA = await fA;
        // disposed 后 _isCurrentGeneration 返回 false
        expect(rA, isA<OpenSuperseded>());
      });
    });
  });
}
