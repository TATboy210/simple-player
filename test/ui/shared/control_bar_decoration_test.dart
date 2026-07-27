// control_bar_decoration_test.dart — Phase 31 Plan 01 (VISUAL-05) 字段等价单测。
//
// 验证 ControlBarDecoration 提取后与原 ControlBar._decorationPlaying /
// _decorationIdle（control_bar.dart 原 L21-73）逐字段等价，且 API 形状符合
// D-03/D-04（默认 controlBarRadius、borderRadius override 生效、idle 4-shadow
// tween 兼容硬约束）。纯 expect 断言，无需 pump（与 panel_color_test.dart
// alias 契约测试同风格）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/control_bar_decoration.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('ControlBarDecoration.playing (D-01/D-04, 源: _decorationPlaying)', () {
    test('color is Tokens.controlBarBg', () {
      expect(ControlBarDecoration.playing().color, Tokens.controlBarBg);
    });

    test('border is 1px Tokens.controlBarBorderWhite', () {
      final decoration = ControlBarDecoration.playing();
      final border = decoration.border;
      // pattern matching 取 Border 具体类型，避免 as 强转
      if (border is Border) {
        expect(border.top.width, 1);
        expect(border.top.color, Tokens.controlBarBorderWhite);
      } else {
        fail('expected Border, got ${border.runtimeType}');
      }
    });

    test('boxShadow has exactly 4 entries (tween-compat 硬约束)', () {
      expect(ControlBarDecoration.playing().boxShadow?.length, 4);
    });

    test('shadow index 3 is Tokens.glowOuterRing (蓝色外环)', () {
      final shadows = ControlBarDecoration.playing().boxShadow;
      expect(shadows?[3].color, Tokens.glowOuterRing);
    });

    test('shadow 0/1/2 逐字段等价转录 spec（顶部内高光/底部内阴影/外层投影）', () {
      final shadows = ControlBarDecoration.playing().boxShadow;
      expect(shadows?[0].color, Tokens.controlBarBorderWhite);
      expect(shadows?[0].offset, const Offset(0, -1));
      expect(shadows?[1].color, Tokens.controlBarShadowBlack);
      expect(shadows?[1].offset, const Offset(0, 1));
      expect(shadows?[2].color, Tokens.controlBarOuterShadow);
      expect(shadows?[2].blurRadius, 32);
      expect(shadows?[2].offset, const Offset(0, 8));
    });

    test('default borderRadius is circular(Tokens.controlBarRadius)', () {
      expect(
        ControlBarDecoration.playing().borderRadius,
        BorderRadius.circular(Tokens.controlBarRadius),
      );
    });

    test('borderRadius override takes effect (面板 chrome corner-only 路径)', () {
      const override = BorderRadius.vertical(
        top: Radius.circular(Tokens.radiusLg),
      );
      expect(
        ControlBarDecoration.playing(borderRadius: override).borderRadius,
        override,
      );
    });
  });

  group('ControlBarDecoration.idle (D-03, 源: _decorationIdle)', () {
    test('boxShadow has exactly 4 entries (DecorationTween index-lerp 不断裂)',
        () {
      // Pitfall 4：idle 必须保留 2 个 transparent padding shadow，
      // 否则 playing↔idle DecorationTween 按 index lerp 时数量不齐插值断裂。
      expect(ControlBarDecoration.idle().boxShadow?.length, 4);
    });

    test('color is Tokens.controlBarBg, border is 1px controlBarBorderIdle', () {
      final decoration = ControlBarDecoration.idle();
      expect(decoration.color, Tokens.controlBarBg);
      final border = decoration.border;
      if (border is Border) {
        expect(border.top.width, 1);
        expect(border.top.color, Tokens.controlBarBorderIdle);
      } else {
        fail('expected Border, got ${border.runtimeType}');
      }
    });

    test('default borderRadius is circular(Tokens.controlBarRadius)', () {
      expect(
        ControlBarDecoration.idle().borderRadius,
        BorderRadius.circular(Tokens.controlBarRadius),
      );
    });
  });

  group('ControlBar 本地 tween 归属 (D-03)', () {
    test('control_bar.dart still owns _decorationTween (tween stays local)', () {
      // D-03：playing/idle 提取至共享，DecorationTween 保留在 control_bar.dart
      // 本地。私有静态字段无法直接访问，用源码存在性断言锁定归属不被误迁。
      final source = File('lib/ui/player/control_bar.dart').readAsStringSync();
      expect(source, contains('_decorationTween'));
      expect(source, contains('ControlBarDecoration.playing()'));
      expect(source, contains('ControlBarDecoration.idle()'));
    });
  });
}
