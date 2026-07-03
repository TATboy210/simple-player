import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// Token alpha 范围验证 — 防止回归到不可见的值
///
/// Phase 18: Visual Tuning & Validation
void main() {
  /// 提取 Color 的 alpha 值（0-255）
  int alphaOf(int colorValue) => (colorValue >> 24) & 0xFF;

  group('Border token alpha', () {
    test('idle blue border alpha >= 15%', () {
      // glassBorderIdle 是 idle 状态的主要可见边框
      final alpha = alphaOf(Tokens.glassBorderIdle.value);
      // 15% of 255 = 38.25
      expect(alpha, greaterThanOrEqualTo(38),
          reason: 'glassBorderIdle alpha=$alpha (${(alpha / 255 * 100).toStringAsFixed(1)}%) must be >= 15%');
    });

    test('playing border alpha > idle border alpha', () {
      // controlBarBorderWhite (playing) 应比 controlBarBorderIdle (idle) 更明显
      final playing = alphaOf(Tokens.controlBarBorderWhite.value);
      final idle = alphaOf(Tokens.controlBarBorderIdle.value);
      expect(playing, greaterThan(idle),
          reason: 'playing=$playing > idle=$idle (fix visibility inversion)');
    });

    test('all controlBar border tokens alpha >= 5%', () {
      final borders = <String, int>{
        'controlBarBorderWhite': alphaOf(Tokens.controlBarBorderWhite.value),
        'controlBarBorderIdle': alphaOf(Tokens.controlBarBorderIdle.value),
        'controlBarBorder': alphaOf(Tokens.controlBarBorder.value),
        'glassBorder': alphaOf(Tokens.glassBorder.value),
        'glassBorderIdle': alphaOf(Tokens.glassBorderIdle.value),
      };
      for (final entry in borders.entries) {
        expect(entry.value, greaterThanOrEqualTo(13),
            reason: '${entry.key} alpha=${entry.value} (${(entry.value / 255 * 100).toStringAsFixed(1)}%) must be >= 5%');
      }
    });
  });

  group('Glass blur tiers', () {
    test('glassBlurThin < glassBlur', () {
      expect(Tokens.glassBlurThin, lessThan(Tokens.glassBlur));
    });

    test('glassBlur is 10.0 (2-tier system)', () {
      // glassBlurThick 已删除，2-tier：Thin=4, Standard=10
      expect(Tokens.glassBlur, equals(10.0));
    });
  });
}
