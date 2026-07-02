import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// 计算 WCAG 相对亮度 (sRGB)
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// 计算两个颜色的 WCAG 对比度
double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// 将前景色 alpha 混合到背景色上
Color _compositeOn(Color fg, Color bg) {
  final a = fg.a;
  return Color.fromARGB(
    255,
    (fg.r * a + bg.r * (1 - a)).round(),
    (fg.g * a + bg.g * (1 - a)).round(),
    (fg.b * a + bg.b * (1 - a)).round(),
  );
}

void main() {
  group('WCAG contrast — textSecondary', () {
    test('textSecondary on bgDeep achieves >= 4.5:1 (WCAG AA)', () {
      final composite = _compositeOn(Tokens.textSecondary, Tokens.bgDeep);
      final ratio = _contrastRatio(composite, Tokens.bgDeep);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'textSecondary contrast ${ratio.toStringAsFixed(2)}:1');
    });

    test('textSecondary on bgDeep achieves target 5.0:1+', () {
      final composite = _compositeOn(Tokens.textSecondary, Tokens.bgDeep);
      final ratio = _contrastRatio(composite, Tokens.bgDeep);
      expect(ratio, greaterThanOrEqualTo(5.0),
          reason: 'target contrast ${ratio.toStringAsFixed(2)}:1');
    });
  });

  group('WCAG contrast — idle text tokens', () {
    test('controlBarTextPrimaryIdle on bgDeep achieves >= 4.5:1', () {
      final composite =
          _compositeOn(Tokens.controlBarTextPrimaryIdle, Tokens.bgDeep);
      final ratio = _contrastRatio(composite, Tokens.bgDeep);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'controlBarTextPrimaryIdle contrast ${ratio.toStringAsFixed(2)}:1');
    });

    test('controlBarTextSecondaryIdle on bgDeep — relaxed for idle state', () {
      final composite =
          _compositeOn(Tokens.controlBarTextSecondaryIdle, Tokens.bgDeep);
      final ratio = _contrastRatio(composite, Tokens.bgDeep);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason:
              'controlBarTextSecondaryIdle contrast ${ratio.toStringAsFixed(2)}:1');
    });
  });

  group('Idle token ratio validation', () {
    double _alphaRatio(Color idle, Color active) => idle.a / active.a;

    test('controlBarBgIdle is 40-60% of controlBarBg alpha', () {
      final ratio = _alphaRatio(Tokens.controlBarBgIdle, Tokens.controlBarBg);
      expect(ratio, greaterThanOrEqualTo(0.4));
      expect(ratio, lessThanOrEqualTo(0.6));
    });

    test('controlBarBorderIdle is 40-60% of controlBarBorderWhite alpha', () {
      final ratio =
          _alphaRatio(Tokens.controlBarBorderIdle, Tokens.controlBarBorderWhite);
      expect(ratio, greaterThanOrEqualTo(0.4));
      expect(ratio, lessThanOrEqualTo(0.6));
    });

    test('glassBorderIdle is 40-60% of glassBorder alpha', () {
      final ratio = _alphaRatio(Tokens.glassBorderIdle, Tokens.glassBorder);
      expect(ratio, greaterThanOrEqualTo(0.4));
      expect(ratio, lessThanOrEqualTo(0.6));
    });

    test('controlBarTextPrimaryIdle is 40-60% of textPrimary alpha', () {
      final ratio =
          _alphaRatio(Tokens.controlBarTextPrimaryIdle, Tokens.textPrimary);
      expect(ratio, greaterThanOrEqualTo(0.4));
      expect(ratio, lessThanOrEqualTo(0.6));
    });

    test('controlBarTextSecondaryIdle is 40-60% of textSecondary alpha', () {
      final ratio =
          _alphaRatio(Tokens.controlBarTextSecondaryIdle, Tokens.textSecondary);
      expect(ratio, greaterThanOrEqualTo(0.4));
      expect(ratio, lessThanOrEqualTo(0.6));
    });
  });

  group('Compile-time const verification', () {
    test('all idle tokens are compile-time constants', () {
      const bg = Tokens.controlBarBgIdle;
      const border = Tokens.controlBarBorderIdle;
      const glass = Tokens.glassBorderIdle;
      const primary = Tokens.controlBarTextPrimaryIdle;
      const secondary = Tokens.controlBarTextSecondaryIdle;
      const icon = Tokens.controlBarIconIdle;
      expect(bg, isNot(Colors.transparent));
      expect(border, isNot(Colors.transparent));
      expect(glass, isNot(Colors.transparent));
      expect(primary, isNot(Colors.transparent));
      expect(secondary, isNot(Colors.transparent));
      expect(icon, isNot(Colors.transparent));
    });
  });
}
