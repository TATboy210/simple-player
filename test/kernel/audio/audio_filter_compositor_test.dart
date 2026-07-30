// AudioFilterCompositor 单元测试 — Phase 33 确定性组合规则（T-33-03）。
//
// 覆盖 EQ 预设表、pan/adelay/dynaudnorm 段组合与省略、链顺序、
// 运行时可用性 probe（注入 fake applier 对特定滤镜抛异常→标记不可用+
// debugPrint 警告）。纯 Dart，无 mdk.dll 依赖。

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_filter_compositor.dart';

void main() {
  const all = AudioFilterAvailability.allSupported;

  group('AudioFilterCompositor.compose — EQ presets', () {
    test('preset 0 (关闭) yields empty string', () {
      const settings = AudioSettings(eqPresetIndex: 0);
      expect(AudioFilterCompositor.compose(settings, all), '');
    });

    test('preset 1 yields bass=g=10', () {
      const settings = AudioSettings(eqPresetIndex: 1);
      expect(AudioFilterCompositor.compose(settings, all), 'bass=g=10');
    });

    test('preset 2 yields treble=g=5', () {
      const settings = AudioSettings(eqPresetIndex: 2);
      expect(AudioFilterCompositor.compose(settings, all), 'treble=g=5');
    });

    test('preset 3 yields bass+treble chain', () {
      const settings = AudioSettings(eqPresetIndex: 3);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'bass=g=8,treble=g=6',
      );
    });

    test('preset 4 yields bass+treble chain', () {
      const settings = AudioSettings(eqPresetIndex: 4);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'bass=g=3,treble=g=4',
      );
    });

    test('out-of-range index is clamped to last preset (defense-in-depth)', () {
      const settings = AudioSettings(eqPresetIndex: 99);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'bass=g=3,treble=g=4',
      );
    });
  });

  group('AudioFilterCompositor.compose — defaults', () {
    test('default AudioSettings yields empty string', () {
      expect(AudioFilterCompositor.compose(const AudioSettings(), all), '');
    });
  });

  group('AudioFilterCompositor.compose — balance/pan', () {
    test('balance 0.0 omits pan segment', () {
      const settings = AudioSettings(balance: 0.0);
      expect(AudioFilterCompositor.compose(settings, all), '');
    });

    test('balance 1.0 (full right) mutes left channel', () {
      const settings = AudioSettings(balance: 1.0);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'pan=stereo|c0=0.00*c0|c1=1.00*c1',
      );
    });

    test('balance -1.0 (full left) mutes right channel', () {
      const settings = AudioSettings(balance: -1.0);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'pan=stereo|c0=1.00*c0|c1=0.00*c1',
      );
    });

    test('balance 0.5 attenuates left, clamps right to 1.0', () {
      // leftGain=(1-0.5)=0.50; rightGain=(1+0.5)=1.5→clamp 1.00
      const settings = AudioSettings(balance: 0.5);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'pan=stereo|c0=0.50*c0|c1=1.00*c1',
      );
    });
  });

  group('AudioFilterCompositor.compose — sync/adelay', () {
    test('syncMs 0 omits adelay segment', () {
      const settings = AudioSettings(syncMs: 0);
      expect(AudioFilterCompositor.compose(settings, all), '');
    });

    test('syncMs 200 yields adelay=200|200', () {
      const settings = AudioSettings(syncMs: 200);
      expect(AudioFilterCompositor.compose(settings, all), 'adelay=200|200');
    });

    test('syncMs 10000 (max) yields adelay=10000|10000', () {
      const settings = AudioSettings(syncMs: 10000);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'adelay=10000|10000',
      );
    });

    test('syncMs 99999 is clamped to 10000', () {
      const settings = AudioSettings(syncMs: 99999);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'adelay=10000|10000',
      );
    });
  });

  group('AudioFilterCompositor.compose — normalization/dynaudnorm', () {
    test('normalization false omits dynaudnorm segment', () {
      const settings = AudioSettings(normalization: false);
      expect(AudioFilterCompositor.compose(settings, all), '');
    });

    test('normalization true yields dynaudnorm=f=500:g=15:p=0.95', () {
      const settings = AudioSettings(normalization: true);
      expect(
        AudioFilterCompositor.compose(settings, all),
        'dynaudnorm=f=500:g=15:p=0.95',
      );
    });
  });

  group('AudioFilterCompositor.compose — chain order', () {
    test(
      'all non-default: EQ → pan → adelay → dynaudnorm (comma-joined)',
      () {
        const settings = AudioSettings(
          eqPresetIndex: 1,
          balance: 0.5,
          syncMs: 200,
          normalization: true,
        );
        expect(
          AudioFilterCompositor.compose(settings, all),
          'bass=g=10,pan=stereo|c0=0.50*c0|c1=1.00*c1,adelay=200|200,'
          'dynaudnorm=f=500:g=15:p=0.95',
        );
      },
    );
  });

  group('AudioFilterCompositor.compose — unavailable filters omitted', () {
    test('unavailable pan with non-zero balance omits pan segment', () {
      const settings = AudioSettings(balance: 0.5);
      const availability = AudioFilterAvailability(pan: false);
      expect(AudioFilterCompositor.compose(settings, availability), '');
    });

    test('unavailable adelay with non-zero sync omits adelay segment', () {
      const settings = AudioSettings(syncMs: 200);
      const availability = AudioFilterAvailability(adelay: false);
      expect(AudioFilterCompositor.compose(settings, availability), '');
    });

    test('unavailable dynaudnorm with normalization omits dynaudnorm segment', () {
      const settings = AudioSettings(normalization: true);
      const availability = AudioFilterAvailability(dynaudnorm: false);
      expect(AudioFilterCompositor.compose(settings, availability), '');
    });

    test('EQ segment always present regardless of runtime availability', () {
      // EQ 预设不经运行时 probe（FFmpeg bass/treble 内建滤镜，假定恒支持）
      const settings = AudioSettings(eqPresetIndex: 1);
      const availability = AudioFilterAvailability(
        pan: false,
        adelay: false,
        dynaudnorm: false,
      );
      expect(AudioFilterCompositor.compose(settings, availability), 'bass=g=10');
    });
  });

  group('AudioFilterAvailability.probe', () {
    test('marks all available when applier never throws', () {
      final availability = AudioFilterAvailability.probe(
        applyFilter: (_) {},
      );
      expect(availability.pan, isTrue);
      expect(availability.adelay, isTrue);
      expect(availability.dynaudnorm, isTrue);
    });

    test('marks pan unavailable + warns when applier throws on pan', () {
      final captured = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        captured.add(message ?? '');
      };
      addTearDown(() => debugPrint = original);

      final availability = AudioFilterAvailability.probe(
        applyFilter: (filter) {
          if (filter.startsWith('pan=')) {
            throw Exception('pan not supported by runtime');
          }
        },
      );

      expect(availability.pan, isFalse);
      expect(availability.adelay, isTrue);
      expect(availability.dynaudnorm, isTrue);
      // 警告含滤镜标识 'pan'
      expect(captured.any((m) => m.contains('pan')), isTrue);
    });

    test('marks adelay unavailable when applier throws on adelay', () {
      final availability = AudioFilterAvailability.probe(
        applyFilter: (filter) {
          if (filter.startsWith('adelay=')) {
            throw Exception('adelay not supported');
          }
        },
      );
      expect(availability.pan, isTrue);
      expect(availability.adelay, isFalse);
      expect(availability.dynaudnorm, isTrue);
    });

    test('marks dynaudnorm unavailable when applier throws on dynaudnorm', () {
      final availability = AudioFilterAvailability.probe(
        applyFilter: (filter) {
          if (filter.startsWith('dynaudnorm=')) {
            throw Exception('dynaudnorm not supported');
          }
        },
      );
      expect(availability.pan, isTrue);
      expect(availability.adelay, isTrue);
      expect(availability.dynaudnorm, isFalse);
    });

    test('does not catch Error subtypes (programming bugs propagate)', () {
      // Error 子类表示编程 bug，probe 不应吞掉（CLAUDE.md "Never catch Error subtypes"）
      expect(
        () => AudioFilterAvailability.probe(
          applyFilter: (_) => throw StateError('bug'),
        ),
        throwsStateError,
      );
    });
  });
}
