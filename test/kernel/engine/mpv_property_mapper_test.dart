/// MpvPropertyMapper 纯函数测试 (v0.0.6 Phase 4).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_property_mapper.dart';
import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';

void main() {
  group('mapVideoEffect', () {
    test('0 = 中性 → mpv 0', () {
      final p = MpvPropertyMapper.mapVideoEffect(
        VideoEffectType.brightness,
        0.0,
      );
      expect(p.key, 'brightness');
      expect(p.value, '0');
    });

    test('边界 clamp — ±1 → ±100, 超界不越', () {
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.brightness, 1.0).value,
        '100',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(
          VideoEffectType.brightness,
          -1.0,
        ).value,
        '-100',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.contrast, 2.0).value,
        '100',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(
          VideoEffectType.saturation,
          -3.0,
        ).value,
        '-100',
      );
    });

    test('四键映射到对应 mpv 属性', () {
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.brightness, 0.5).key,
        'brightness',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.contrast, 0.5).key,
        'contrast',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.saturation, 0.5).key,
        'saturation',
      );
      expect(
        MpvPropertyMapper.mapVideoEffect(VideoEffectType.hue, 0.5).key,
        'hue',
      );
    });
  });

  group('mapRotation', () {
    test('四档角度 → video-rotate 字符串', () {
      expect(MpvPropertyMapper.mapRotation(0).value, '0');
      expect(MpvPropertyMapper.mapRotation(90).value, '90');
      expect(MpvPropertyMapper.mapRotation(180).value, '180');
      expect(MpvPropertyMapper.mapRotation(270).value, '270');
      expect(MpvPropertyMapper.mapRotation(0).key, 'video-rotate');
    });
  });

  group('mapDeinterlace / mapHardwareDecoding', () {
    test('布尔 → yes/no 与 auto/no', () {
      expect(MpvPropertyMapper.mapDeinterlace(true).value, 'yes');
      expect(MpvPropertyMapper.mapDeinterlace(false).value, 'no');
      expect(MpvPropertyMapper.mapDeinterlace(true).key, 'deinterlace');
      expect(MpvPropertyMapper.mapHardwareDecoding(true).value, 'auto');
      expect(MpvPropertyMapper.mapHardwareDecoding(false).value, 'no');
      expect(MpvPropertyMapper.mapHardwareDecoding(true).key, 'hwdec');
    });
  });

  group('mapDelay', () {
    test('毫秒 → 秒 3 位小数, 支持负值', () {
      expect(MpvPropertyMapper.mapDelay('sub-delay', 1500).value, '1.500');
      expect(MpvPropertyMapper.mapDelay('sub-delay', -250).value, '-0.250');
      expect(MpvPropertyMapper.mapDelay('audio-delay', 0).value, '0.000');
      expect(
        MpvPropertyMapper.mapDelay('audio-delay', 1500).key,
        'audio-delay',
      );
    });
  });

  group('mapAspectRatio', () {
    test('keepOriginal → no', () {
      final p = MpvPropertyMapper.mapAspectRatio(
        AspectRatioMode.keepOriginal.mdkValue,
      );
      expect(p, isNotNull);
      expect(p!.value, 'no');
    });

    test('标准比率 → mpv 比率语法', () {
      expect(
        MpvPropertyMapper.mapAspectRatio(AspectRatioMode.ratio4_3.mdkValue)!
            .value,
        '4:3',
      );
      expect(
        MpvPropertyMapper.mapAspectRatio(AspectRatioMode.ratio16_9.mdkValue)!
            .value,
        '16:9',
      );
      expect(
        MpvPropertyMapper.mapAspectRatio(AspectRatioMode.ratio21_9.mdkValue)!
            .value,
        '21:9',
      );
    });

    test('stretch/cropFill — 单属性不可表达, 返回 null (诚实降级)', () {
      expect(
        MpvPropertyMapper.mapAspectRatio(AspectRatioMode.stretch.mdkValue),
        isNull,
      );
      expect(
        MpvPropertyMapper.mapAspectRatio(AspectRatioMode.cropFill.mdkValue),
        isNull,
      );
    });

    test('未知 mdk 常量 — 防御返回 null', () {
      expect(MpvPropertyMapper.mapAspectRatio(2.718281828), isNull);
    });
  });

  group('mapVolumeToMpv / mapVolumeFromMpv — 感知音量曲线 (v0.0.8.1)', () {
    test('边界幂等 — 0→0, 1→100 unity', () {
      expect(MpvPropertyMapper.mapVolumeToMpv(0.0), 0.0);
      expect(MpvPropertyMapper.mapVolumeToMpv(1.0), closeTo(100.0, 1e-9));
    });

    test('立方根反演 — 0.5 → ≈79.37 (感知半响度)', () {
      // mpv 软增益是立方 gain=(v/100)³: v=79.37 → gain=0.5.
      expect(MpvPropertyMapper.mapVolumeToMpv(0.5), closeTo(79.3701, 0.001));
    });

    test('超界 clamp — 负值/超 1 均不越界', () {
      expect(MpvPropertyMapper.mapVolumeToMpv(-0.5), 0.0);
      expect(MpvPropertyMapper.mapVolumeToMpv(1.5), closeTo(100.0, 1e-9));
    });

    test('round-trip 互逆 — setVolume 写入与回声反演回环恒等', () {
      for (final u in [0.1, 0.3, 0.5, 0.7, 0.9]) {
        final mpv = MpvPropertyMapper.mapVolumeToMpv(u);
        expect(
          MpvPropertyMapper.mapVolumeFromMpv(mpv),
          closeTo(u, 1e-6),
          reason: 'u=$u 回环应恒等',
        );
      }
    });

    test('mapVolumeFromMpv — 立方正演 + 输入 clamp + v=100 浮点安全', () {
      expect(MpvPropertyMapper.mapVolumeFromMpv(0.0), 0.0);
      // v=79.3701 → gain=(0.7937)³ ≈ 0.5.
      expect(MpvPropertyMapper.mapVolumeFromMpv(79.3701), closeTo(0.5, 1e-6));
      // v=100 立方后浮点可能微超 1.0 — clamp 保证.
      final v = MpvPropertyMapper.mapVolumeFromMpv(100.0);
      expect(v, lessThanOrEqualTo(1.0));
      // 外部异常值 (负数/超 100) 同样安全.
      expect(MpvPropertyMapper.mapVolumeFromMpv(-10.0), 0.0);
      expect(MpvPropertyMapper.mapVolumeFromMpv(250.0), lessThanOrEqualTo(1.0));
    });
  });

  group('mapMute — mpv 原生静音 (v0.0.8.1)', () {
    test('布尔 → yes/no, 键为 mute', () {
      expect(MpvPropertyMapper.mapMute(true).value, 'yes');
      expect(MpvPropertyMapper.mapMute(false).value, 'no');
      expect(MpvPropertyMapper.mapMute(true).key, 'mute');
    });
  });
}
