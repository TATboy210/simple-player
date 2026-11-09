import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 播放列表滚轮平滑滚动 (v0.0.11 T4) — wheel delta 换 easeOutCubic 滑行.
///
/// Registers into the SDK [PointerSignalResolver] auction so the Scrollable's
/// own instant-jump handler (flutter#31658) loses. 命中测试自最深叶起派发,
/// 因此 [onSignal] 必须挂在 viewportBuilder 内层 Listener 上.
class PlaylistWheelGlide {
  /// 创建滚轮滑行器 — 自带滚动控制器, 由 [dispose] 释放.
  PlaylistWheelGlide();

  /// 被驱动的滚动控制器 (Scrollbar 与 Scrollable 共用).
  final ScrollController controller = ScrollController();

  /// 释放滚动控制器.
  void dispose() => controller.dispose();

  /// 滚轮信号入口 — 注册进 PointerSignalResolver 竞拍.
  ///
  /// resolver 规则: 同一 signal 事件只有第一个 register 的回调生效.
  void onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // 首帧空 content dimension 守卫 — 此时 min/maxScrollExtent 尚不可用.
    if (!controller.position.hasContentDimensions) return;
    GestureBinding.instance.pointerSignalResolver.register(event, _onWon);
  }

  /// resolver 中标回调 — wheel delta 换滑行动画.
  void _onWon(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _glide(event.scrollDelta.dy);
  }

  /// 从当前 pixels 滑向 clamp 目标 — 连发时 animateTo 自动取消前段并
  /// 从当前位置接力重算; 已在边界 (target == pixels) 时空转不建动画,
  /// 不打断在飞的滑行.
  void _glide(double delta) {
    final position = controller.position;
    final target = clampDouble(
      position.pixels + delta,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    unawaited(
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: Tokens.playlistWheelGlideMs),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
