/// VolumeResyncGate 纯逻辑测试 (v0.0.8.1) — WASAPI 首播音量 re-sync 门.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/volume_resync_gate.dart';

void main() {
  group('VolumeResyncGate', () {
    test('未 arm — 不消费', () {
      final gate = VolumeResyncGate();

      expect(gate.isArmed, isFalse);
      expect(gate.consumeOnPlaying(), isFalse);
    });

    test('arm 后首个 playing 消费一次, 第二次不消费', () {
      final gate = VolumeResyncGate();
      gate.arm();
      expect(gate.isArmed, isTrue);

      expect(gate.consumeOnPlaying(), isTrue, reason: '首个 playing 消费');
      expect(gate.isArmed, isFalse);
      expect(gate.consumeOnPlaying(), isFalse, reason: 'consume-once');
    });

    test('重复 arm 幂等 — 新装载覆盖旧挂起, 仍只消费一次', () {
      final gate = VolumeResyncGate();
      gate.arm();
      gate.arm();

      expect(gate.consumeOnPlaying(), isTrue);
      expect(gate.consumeOnPlaying(), isFalse);
    });

    test('arm → 消费 → 再 arm — 新一轮窗口', () {
      final gate = VolumeResyncGate();
      gate.arm();
      gate.consumeOnPlaying();

      gate.arm();
      expect(gate.consumeOnPlaying(), isTrue, reason: '切曲后重新 arm');
    });
  });
}
