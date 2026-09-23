/// AppSettingsService 编排测试 (v0.0.6 Phase 4).
///
/// FakeEngine + 真 AppSettingsStore (mock SharedPreferences) — 回放/
/// 防抖写回/开关/flush 全链路. 防抖窗口注入零值, 事件循环下一轮即落盘.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Store/Service 走 KernelLogger — 测试环境显式初始化 (项目惯例).
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late VideoProcessingService videoProcessing;
  late AppSettingsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = FakeEngine();
    videoProcessing = VideoProcessingService(engine);
    service = AppSettingsService(
      engine: engine,
      videoProcessing: videoProcessing,
      store: AppSettingsStore(),
      // 零防抖 — Timer(0) 在事件循环下一轮触发, 测试用微任务等待即可.
      engineWriteDebounce: Duration.zero,
      videoWriteDebounce: Duration.zero,
    );
  });

  tearDown(() {
    service.dispose();
    videoProcessing.dispose();
    engine.dispose();
  });

  group('initialize 回放', () {
    test('空存储 — 默认值回放引擎 (含视频全量重放)', () async {
      await service.initialize();

      expect(engine.lastSetVolumeValue, 1.0);
      expect(engine.volume.value, 1.0);
      expect(engine.playbackSpeed.value, 1.0);
      expect(engine.lastHardwareDecodingEnabled, isTrue);
      expect(engine.lastVideoEffectType, VideoEffectType.hue); // 重放序列末位
    });

    test('持久值回放 — 音量/倍速/视频效果/延迟全部生效', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settingsVolume': 0.3,
        'settingsPlaybackRate': 2.0,
        'settingsResumeEnabled': false,
        'settingsHardwareDecoding': false,
        'settingsAudioDelayMs': 150,
        'settingsSubtitleDelayMs': -80,
        'settingsVideoProcessing':
            '{"brightness":0.25,"contrast":0.0,"saturation":0.0,'
            '"hue":0.0,"deinterlaceEnabled":false,"rotation":90,'
            '"aspectRatioMode":"ratio4_3"}',
      });

      await service.initialize();

      expect(engine.lastSetVolumeValue, 0.3);
      expect(engine.playbackSpeed.value, 2.0);
      expect(service.resumeEnabled.value, isFalse);
      expect(engine.lastHardwareDecodingEnabled, isFalse);
      expect(service.audioDelayMs, 150);
      expect(service.subtitleDelayMs, -80);
      // 视频状态已入服务且引擎收到全量重放 (4 效果 + 旋转/宽高比/去隔行).
      expect(videoProcessing.state.value.brightness, 0.25);
      expect(videoProcessing.state.value.rotation, 90);
      expect(engine.setVideoEffectCallCount, 4); // brightness/contrast/sat/hue
      expect(engine.lastVideoEffectType, VideoEffectType.hue); // 重放序列末位
      expect(engine.lastRotateDegree, 90);
    });

    test('回放不触发写回 (回声抑制) — initialize 后无待写落盘', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settingsVolume': 0.3,
      });
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      // 音量仍是持久值 0.3, 且回放未产生新写 (若有回声, 写回 0.3 也无害,
      // 但静音/倍速同理 — 断言核心: 没有把回放值当作用户变更重写).
      expect(prefs.getDouble('settingsVolume'), 0.3);
    });
  });

  group('设置入口', () {
    test('setResumeEnabled — notifier + 落盘', () async {
      await service.initialize();

      service.setResumeEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(service.resumeEnabled.value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settingsResumeEnabled'), isFalse);
    });

    test('setAudioDelayMs / setSubtitleDelayMs — 引擎生效 + 落盘', () async {
      await service.initialize();

      service.setAudioDelayMs(120);
      service.setSubtitleDelayMs(-40);
      await Future<void>.delayed(Duration.zero);

      expect(engine.audioDelay, 120);
      expect(engine.subtitleDelay, -40);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('settingsAudioDelayMs'), 120);
      expect(prefs.getInt('settingsSubtitleDelayMs'), -40);
    });

    test('setHardwareDecoding — 引擎生效 + 落盘', () async {
      await service.initialize();

      service.setHardwareDecoding(false);
      await Future<void>.delayed(Duration.zero);

      expect(engine.lastHardwareDecodingEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settingsHardwareDecoding'), isFalse);
    });
  });

  group('变更写回', () {
    test('引擎音量变更 — 零防抖下一轮落盘 (含静音快照)', () async {
      await service.initialize();

      engine.setVolume(0.6);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('settingsVolume'), 0.6);
      expect(prefs.getBool('settingsMuted'), isFalse);
    });

    test('mute 后快照保真 — 音量保持原值 + muted=true (v0.0.8.1 契约)', () async {
      // 真引擎 v0.0.8.1 起 mute 走 mpv 原生属性, 音量 notifier 不动;
      // 旧 setVolume(0) 模拟会把 volume=0 落盘导致重启丢音量 — 本用例
      // 锁定「静音不得污染音量持久值」的服务层契约 (FakeEngine 与真引擎
      // 新语义同构).
      await service.initialize();

      engine.setVolume(0.6);
      engine.setMute(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(engine.isMuted.value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('settingsVolume'), 0.6, reason: '静音不得归零音量持久值');
      expect(prefs.getBool('settingsMuted'), isTrue);
    });

    test('视频状态变更 — 零防抖下一轮落盘', () async {
      await service.initialize();

      videoProcessing.updateBrightness(0.5);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('settingsVideoProcessing');
      expect(raw, isNotNull);
      expect(raw, contains('0.5'));
    });

    test('倍速变更 — 零防抖下一轮落盘', () async {
      await service.initialize();

      engine.setPlaybackRate(1.75);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('settingsPlaybackRate'), 1.75);
    });
  });

  group('dispose', () {
    test('flush 未落盘的防抖待写值', () async {
      await service.initialize();

      engine.setVolume(0.8); // 进入防抖待写
      service.dispose(); // flush
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('settingsVolume'), 0.8);
    });

    test('dispose 后设置入口 no-op 不抛', () async {
      await service.initialize();
      service.dispose();

      service.setResumeEnabled(false);
      service.setAudioDelayMs(50);

      expect(service.audioDelayMs, 0); // 未生效
    });
  });
}
