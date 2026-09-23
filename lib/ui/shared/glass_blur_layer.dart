import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'glass_container.dart';

/// 统一玻璃模糊层 — ClipRRect + BackdropFilter + 门控收敛点 (v0.0.8.2)。
///
/// Unified glass blur layer — single gating funnel for all raw
/// [BackdropFilter] sites (control bar / panels / dialogs / menus).
///
/// 性能语义（与既有先例逐字一致）：
/// - filter 恒传 [GlassTier] 缓存单例（零分配，glass_container.dart 先例）；
///   blur 成本 ≈ 面积×sigma，本层负责在**不可见/挂起时把 enabled 置 false**
///   停用 GPU 背景采样（BackdropFilter.enabled=false 时跳过 saveLayer）
/// - enabled 翻转只换 `BackdropFilter.enabled` 布尔，子树与祖先拓扑恒定
///   （resize 冻结先例 glass_container.dart 同款语义）— 无渲染层结构
///   重建，AX 链不破坏，恢复无跳变
/// - child 外层恒包 [RepaintBoundary]，隔离外部重绘对玻璃子树的连带
///
/// 与 [GlassContainer] 的分工：本层只管"裸模糊层"（菜单/确认条/对话框/
/// 面板壳的 BackdropFilter 散点收敛）；完整玻璃容器（装饰+容器+blur 一体）
/// 仍用 GlassContainer，两者并存。
class GlassBlurLayer extends StatelessWidget {
  const GlassBlurLayer({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.filter,
    this.opacity,
    this.suspend,
    this.enabled = true,
  });

  /// 玻璃面内容 — build 期间作为常量子树传入 AnimatedBuilder，
  /// 门控翻转不重建此子树。
  final Widget child;

  /// 模糊区域圆角裁剪 — blur 面积与圆角外的采样一并排除。
  final BorderRadius borderRadius;

  /// 模糊滤镜 — 缺省 normal 档缓存单例。
  final ImageFilter? filter;

  /// 淡入门控 — value < 0.01 时停用模糊（隐藏/淡出尾段零合成成本；
  /// ControlBar opacity 门控同语义）。通常传面板的 fade Animation。
  final Animation<double>? opacity;

  /// 挂起门控 — true 时强制停用（如 seek 拖动期间，v0.0.8.2 C1）。
  final ValueListenable<bool>? suspend;

  /// 静态总开关 — false 恒停用（低配降级通路，D-14 同义）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = this.opacity;
    final suspend = this.suspend;
    // 无任何动态门控源 → 恒定结构，不引入 AnimatedBuilder。
    if (opacity == null && suspend == null) {
      return _buildBlur(constantChild, enabled: enabled);
    }
    final sources = <Listenable>[?opacity, ?suspend];
    return AnimatedBuilder(
      animation: Listenable.merge(sources),
      // 常量子树 — 门控翻转零重建契约（与控制栏/设置面板先例一致）。
      child: constantChild,
      builder: (context, child) {
        // 门控语义: enabled(静态) && 可见(opacity≥0.01) && 未挂起(!suspend).
        final visible = (opacity?.value ?? 1) >= 0.01;
        final suspended = suspend?.value ?? false;
        return _buildBlur(
          child ?? constantChild,
          enabled: enabled && visible && !suspended,
        );
      },
    );
  }

  Widget get constantChild => RepaintBoundary(child: child);

  Widget _buildBlur(Widget child, {required bool enabled}) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: filter ?? GlassTier.normal.blurFilter,
      enabled: enabled,
      child: child,
    ),
  );
}
