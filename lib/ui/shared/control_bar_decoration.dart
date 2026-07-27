// control_bar_decoration.dart — Phase 31 Plan 01 (D-01/D-02) 新增。
//
// 控制栏装饰的共享单一事实源：从 lib/ui/player/control_bar.dart 的
// _decorationPlaying / _decorationIdle 逐字提取（31-RESEARCH.md §5 转录 spec），
// 供控制栏与设置面板 chrome 三段（标题栏 / tab 条 / 按钮栏）双向复用。
//
// 不提取的部分（仍为控制栏专属 chrome 增强）：EdgeGlow 包装、_buildBlur 的
// ClipRRect+BackdropFilter、顶部渐变光线 DecoratedBox——面板 chrome 不采纳。

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 控制栏装饰 — 深色毛玻璃 + 蓝色微光边框（D-02: 控制栏为视觉基准，面板是 adopter）。
///
/// 双向复用（D-01）：
/// - control_bar.dart：无参调用，默认 `Tokens.controlBarRadius` 圆角；
/// - settings_overlay_shell.dart / tab_strip.dart：面板 chrome 三段以
///   `borderRadius` 参数传 corner-only 圆角（Pitfall 1 段间阴影接缝缓解）。
///
/// tween 保留在 control_bar.dart 本地（D-03），本类只提供静态装饰工厂。
class ControlBarDecoration {
  /// 私有构造 — 纯静态工厂类，禁止实例化。
  ControlBarDecoration._();

  /// 默认圆角 — 控制栏无参调用使用（D-04: `Tokens.controlBarRadius`）。
  static final _defaultRadius = BorderRadius.circular(Tokens.controlBarRadius);

  /// playing 装饰 — 4-shadow（源: `ControlBar._decorationPlaying`，control_bar.dart L21-49）。
  ///
  /// 面板 chrome 恒用 playing 装饰（视觉对齐，非状态对齐；面板无 playing/idle 状态机）。
  static BoxDecoration playing({BorderRadius? borderRadius}) => BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: borderRadius ?? _defaultRadius,
    border: Border.all(color: Tokens.controlBarBorderWhite, width: 1),
    boxShadow: const [
      // CSS: inset 0 1px 0 rgba(255,255,255,0.04) — 顶部内高光
      BoxShadow(
        color: Tokens.controlBarBorderWhite,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, -1),
      ),
      // CSS: inset 0 -1px 0 rgba(0,0,0,0.1) — 底部内阴影
      BoxShadow(
        color: Tokens.controlBarShadowBlack,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, 1),
      ),
      // CSS: 0 8px 32px rgba(0,0,0,0.25) — 外层投影
      BoxShadow(
        color: Tokens.controlBarOuterShadow,
        blurRadius: 32,
        offset: Offset(0, 8),
      ),
      // CSS: 0 0 0 1px rgba(80,130,255,0.04) — 蓝色外环
      BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),
    ],
  );

  /// idle 装饰 — 2% 淡蓝描边 + 补齐 4 个 BoxShadow（源: `ControlBar._decorationIdle`，L52-73）。
  ///
  /// 4-shadow 列表（含 2 个 transparent padding）是硬约束：`DecorationTween`
  /// 按 index lerp BoxShadow 列表，数量不齐会导致 playing↔idle 插值断裂
  /// （Pitfall 4；control_bar.dart 原 L69 注释）。提取必须逐字保留。
  static BoxDecoration idle({BorderRadius? borderRadius}) => BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: borderRadius ?? _defaultRadius,
    border: Border.all(color: Tokens.controlBarBorderIdle, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Tokens.controlBarBorderIdle,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, -1),
      ),
      BoxShadow(
        color: Tokens.controlBarShadowBlack,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, 1),
      ),
      // 补齐 4 个 BoxShadow，让 DecorationTween 插值更平滑（原 D-04 注释）
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
    ],
  );
}
