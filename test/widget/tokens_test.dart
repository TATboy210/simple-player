import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// Token alpha 范围验证 — 防止回归到不可见的值
///
/// Phase 18: Visual Tuning & Validation
void main() {
  /// 提取 Color 的 alpha 值（0-255）
  int alphaOf(Color color) => (color.a * 255).round();

  group('Border token alpha', () {
    test('idle blue border alpha >= 15%', () {
      // glassBorderIdle 是 idle 状态的主要可见边框
      final alpha = alphaOf(Tokens.glassBorderIdle);
      // 15% of 255 = 38.25
      expect(alpha, greaterThanOrEqualTo(38),
          reason: 'glassBorderIdle alpha=$alpha (${(alpha / 255 * 100).toStringAsFixed(1)}%) must be >= 15%');
    });

    test('playing border alpha > idle border alpha', () {
      // controlBarBorderWhite (playing) 应比 controlBarBorderIdle (idle) 更明显
      final playing = alphaOf(Tokens.controlBarBorderWhite);
      final idle = alphaOf(Tokens.controlBarBorderIdle);
      expect(playing, greaterThan(idle),
          reason: 'playing=$playing > idle=$idle (fix visibility inversion)');
    });

    test('all controlBar border tokens alpha >= 5%', () {
      final borders = <String, int>{
        'controlBarBorderWhite': alphaOf(Tokens.controlBarBorderWhite),
        'controlBarBorderIdle': alphaOf(Tokens.controlBarBorderIdle),
        'controlBarBorder': alphaOf(Tokens.controlBarBorder),
        'glassBorder': alphaOf(Tokens.glassBorder),
        'glassBorderIdle': alphaOf(Tokens.glassBorderIdle),
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

    test('glassBlur is 11.5 (+15% from 10.0)', () {
      // Phase 2: 提升毛玻璃模糊质感
      expect(Tokens.glassBlur, equals(11.5));
    });
  });
}
