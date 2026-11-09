import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'glass_container.dart';
import '../theme/tokens.dart';

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
/// - child 外层恒包 [RepaintBoundary]：仅隔离 enabled 翻转时 child 的
///   重绘（µs 级收益）。**它不隔断"视频每帧变化 → blur 重算"链** —
///   backdrop 采样由 layer tree 中背景内容变化触发，与 child 侧边界
///   无关；停掉视频期 blur 重算的唯一手段是 enabled=false 门控
///
/// 与 [GlassContainer] 的分工：本层只管"裸模糊层"（菜单/确认条/对话框/
/// 面板壳的 BackdropFilter 散点收敛）；完整玻璃容器（装饰+容器+blur 一体）
/// 仍用 GlassContainer，两者并存。resize：控制栏视觉恒定契约要求 blur 恒开
/// （438e76a9 实测量裁），故 [resizing] 默认 null；面板壳显式传入以在拖拽
/// 缩放期间挂起 blur（面板常驻视频之上，σ11.5 采样是 raster 主成本之一）。
class GlassBlurLayer extends StatelessWidget {
  const GlassBlurLayer({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.filter,
    this.opacity,
    this.suspend,
    this.resizing,
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

  /// 窗口 resize 挂起门控（可选）— true 时停用模糊，拖拽缩放期间不再对
  /// 每帧变化的视频纹理做 σ≈11.5 的背景采样。仅面板壳接入；控制栏走自身
  /// 淡出路径，不传此参数（视觉恒定契约不变）。
  final ValueListenable<bool>? resizing;

  /// 静态总开关 — false 恒停用（低配降级通路，D-14 同义）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = this.opacity;
    final suspend = this.suspend;
    final resizing = this.resizing;
    // 无任何动态门控源 → 恒定结构，不引入 AnimatedBuilder。
    if (opacity == null && suspend == null && resizing == null) {
      return _buildBlur(constantChild, enabled: enabled);
    }
    final sources = <Listenable>[?opacity, ?suspend, ?resizing];
    return AnimatedBuilder(
      animation: Listenable.merge(sources),
      // 常量子树 — 门控翻转零重建契约（与控制栏/设置面板先例一致）。
      child: constantChild,
      builder: (context, child) {
        // 编程错误守卫: child 缺失会让每帧 builder 新建子树, 静默破坏
        // 零重建契约 — debug 下立即失败优于静默退化.
        assert(child != null, 'child 必须传入 AnimatedBuilder 以保零重建契约');
        // 门控语义: enabled(静态) && 可见(opacity≥0.01) && 未挂起(!suspend).
        final visible = (opacity?.value ?? 1) >= 0.01;
        final suspended =
            (suspend?.value ?? false) || (resizing?.value ?? false);
        return _buildBlur(child!, enabled: enabled && visible && !suspended);
      },
    );
  }

  Widget get constantChild => RepaintBoundary(child: child);

  Widget _buildBlur(Widget child, {required bool enabled}) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: filter ?? GlassTier.normal.blurFilter,
      // 编译期取证开关在此单点收敛 — A/B 时全应用 blur 经由此处停用。
      enabled: enabled && !Tokens.blurDisabled,
      child: child,
    ),
  );
}
