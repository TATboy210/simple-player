// ignore_for_file: no-empty-block
/// VideoProcessingService 单测 — 不可变状态 / diff 同步 / loadFrom / reapplyAll.
///
/// 使用 FakeEngine (无 libmpv FFI), 全部同步, 无真实延时.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/models/video_processing_state.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';

import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;
  late VideoProcessingService service;

  setUp(() {
    engine = FakeEngine();
    service = VideoProcessingService(engine);
  });

  tearDown(() {
    service.dispose();
    engine.dispose();
  });

  group('VideoProcessingService', () {
    test('初始状态为 defaults 且不触碰引擎', () {
      expect(service.state.value, VideoProcessingState.defaults);
      expect(engine.setVideoEffectCallCount, 0);
      expect(engine.rotateCallCount, 0);
    });

    test('updateBrightness — 只推送变化的属性 (diff-based)', () {
      service.updateBrightness(0.5);

      expect(engine.setVideoEffectCallCount, 1, reason: '不重复推 contrast/饱和/色调');
      expect(engine.lastVideoEffectType, VideoEffectType.brightness);
      expect(engine.lastVideoEffectValue, 0.5);
      expect(engine.rotateCallCount, 0);
      expect(engine.setDeinterlaceCallCount, 0);
      expect(engine.setAspectRatioCallCount, 0);
    });

    test('各 update* 映射到正确的引擎调用', () {
      service.updateContrast(0.2);
      expect(engine.lastVideoEffectType, VideoEffectType.contrast);
      service.updateSaturation(0.3);
      expect(engine.lastVideoEffectType, VideoEffectType.saturation);
      service.updateHue(0.4);
      expect(engine.lastVideoEffectType, VideoEffectType.hue);
      expect(engine.lastVideoEffectValue, 0.4);

      service.updateDeinterlace(true);
      expect(engine.lastDeinterlaceValue, isTrue);
      service.updateRotation(90);
      expect(engine.lastRotateDegree, 90);
      service.updateAspectRatio(AspectRatioMode.ratio16_9);
      expect(engine.lastAspectRatioValue, AspectRatioMode.ratio16_9.mdkValue);

      expect(engine.setVideoEffectCallCount, 3);
    });

    test('写入相同值 — 引擎零新增调用', () {
      service.updateRotation(180);
      final before = engine.rotateCallCount;

      service.updateRotation(180); // 同值: 状态相等, diff 恒空

      expect(engine.rotateCallCount, before);
    });

    test('状态不可变 — update 产生新实例, 旧快照不被修改', () {
      final before = service.state.value;

      service.updateBrightness(0.7);

      expect(identical(service.state.value, before), isFalse);
      expect(before.brightness, 0.0, reason: '旧快照保持原值');
      expect(service.state.value.brightness, 0.7);
    });

    test('resetAll — 回到 defaults 并把被改动的属性推回引擎', () {
      service
        ..updateBrightness(0.5)
        ..updateRotation(90);
      final effectCalls = engine.setVideoEffectCallCount;
      final rotateCalls = engine.rotateCallCount;

      service.resetAll();

      expect(service.state.value, VideoProcessingState.defaults);
      expect(engine.setVideoEffectCallCount, effectCalls + 1);
      expect(engine.lastVideoEffectValue, 0.0);
      expect(engine.rotateCallCount, rotateCalls + 1);
      expect(engine.lastRotateDegree, 0);
    });

    test('loadFrom — 更新视图但不触发引擎 diff', () {
      const loaded = VideoProcessingState(brightness: 0.3, rotation: 270);

      service.loadFrom(loaded);

      expect(service.state.value, loaded);
      expect(engine.setVideoEffectCallCount, 0);
      expect(engine.rotateCallCount, 0);

      // 基线已同步为 loaded — 同值更新不再推送.
      service.updateRotation(270);
      expect(engine.rotateCallCount, 0);
    });

    test('reapplyAll — 全量推送 7 个属性', () {
      service.loadFrom(
        const VideoProcessingState(
          brightness: 0.1,
          contrast: 0.2,
          saturation: 0.3,
          hue: 0.4,
          deinterlaceEnabled: true,
          rotation: 90,
          aspectRatioMode: AspectRatioMode.ratio4_3,
        ),
      );

      service.reapplyAll();

      expect(engine.setVideoEffectCallCount, 4);
      expect(engine.lastVideoEffectType, VideoEffectType.hue);
      expect(engine.setDeinterlaceCallCount, 1);
      expect(engine.lastDeinterlaceValue, isTrue);
      expect(engine.lastRotateDegree, 90);
      expect(engine.lastAspectRatioValue, AspectRatioMode.ratio4_3.mdkValue);
    });

    test('dispose 幂等 — 二次 dispose 不抛, notifier 已释放', () {
      final state = service.state;
      service.dispose();
      service.dispose();

      expect(() => state.addListener(() {}), throwsStateError);
      expect(engine.setVideoEffectCallCount, 0);
    });
  });
}
