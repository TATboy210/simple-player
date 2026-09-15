/// AppSettingsStore 往返与容错测试 (v0.0.6 Phase 4).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/features/player/models/video_processing_state.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsStore', () {
    test('默认值 — 无存储时返回全默认', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = AppSettingsStore();

      final data = await store.load();

      expect(data.volume, 1.0);
      expect(data.isMuted, isFalse);
      expect(data.playbackRate, 1.0);
      expect(data.resumeEnabled, isTrue);
      expect(data.hardwareDecoding, isTrue);
      expect(data.audioDelayMs, 0);
      expect(data.subtitleDelayMs, 0);
      expect(data.video, VideoProcessingState.defaults);
    });

    test('save → load 往返保真', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = AppSettingsStore();

      await store.saveVolume(0.4);
      await store.saveMuted(true);
      await store.savePlaybackRate(1.5);
      await store.saveResumeEnabled(false);
      await store.saveHardwareDecoding(false);
      await store.saveAudioDelayMs(200);
      await store.saveSubtitleDelayMs(-300);
      await store.saveVideo(
        const VideoProcessingState(
          brightness: 0.2,
          contrast: -0.1,
          saturation: 0.3,
          hue: 0.4,
          deinterlaceEnabled: true,
          rotation: 90,
          aspectRatioMode: AspectRatioMode.ratio16_9,
        ),
      );

      final data = await store.load();

      expect(data.volume, 0.4);
      expect(data.isMuted, isTrue);
      expect(data.playbackRate, 1.5);
      expect(data.resumeEnabled, isFalse);
      expect(data.hardwareDecoding, isFalse);
      expect(data.audioDelayMs, 200);
      expect(data.subtitleDelayMs, -300);
      expect(data.video.brightness, 0.2);
      expect(data.video.contrast, -0.1);
      expect(data.video.saturation, 0.3);
      expect(data.video.hue, 0.4);
      expect(data.video.deinterlaceEnabled, isTrue);
      expect(data.video.rotation, 90);
      expect(data.video.aspectRatioMode, AspectRatioMode.ratio16_9);
    });

    test('逐字段容错 — 损坏视频 JSON 回退默认, 其余字段保留', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settingsVolume': 0.7,
        'settingsVideoProcessing': '{broken',
      });
      final store = AppSettingsStore();

      final data = await store.load();

      expect(data.volume, 0.7); // 好字段保留
      expect(data.video, VideoProcessingState.defaults); // 坏字段回退
    });

    test('越界值 clamp — 音量 5.0 → 1.0, 倍速 100 → 4.0', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settingsVolume': 5.0,
        'settingsPlaybackRate': 100.0,
      });
      final store = AppSettingsStore();

      final data = await store.load();

      expect(data.volume, 1.0);
      expect(data.playbackRate, 4.0);
    });
  });
}
