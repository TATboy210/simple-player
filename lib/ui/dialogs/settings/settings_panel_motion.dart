part of 'settings_panel.dart';

/// 面板动画集合 — 渐入渐出 + 层级切换两组 controller/曲线的统一持有者。
///
/// Owns the fade controller (panel show/hide) and the layer controller
/// (L0 ↔ L1 slide); both need a [TickerProvider], so they are created in
/// `initState` through this single holder and disposed together.
class _PanelMotion {
  /// 以 [vsync] 创建两组动画；[visible] 决定面板初始显隐值.
  factory _PanelMotion({required TickerProvider vsync, required bool visible}) {
    final fadeController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = visible ? 1.0 : 0.0;
    final layerController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: Tokens.durationNormal),
    );
    return _PanelMotion._(fadeController, layerController);
  }

  _PanelMotion._(this.fadeController, this.layerController)
    // 与控制栏/播放列表同款：easeInOut + durationControlsFade.
    : fade = CurvedAnimation(parent: fadeController, curve: Curves.easeInOut),
      // L0 虚化 + L1 滑入共用（150ms easeInOut，与家族同节奏）.
      layerEase = CurvedAnimation(
        parent: layerController,
        curve: Curves.easeInOut,
      );

  /// 面板显隐驱动.
  final AnimationController fadeController;

  /// 层级切换驱动（0 = L0，1 = L1）.
  final AnimationController layerController;

  /// 显隐曲线（FadeTransition / GlassBlurLayer 共用）.
  final CurvedAnimation fade;

  /// 层级曲线（L0 退场 / L1 滑入 / 返回按钮淡入共用）.
  final CurvedAnimation layerEase;

  /// 释放曲线与 controller（先曲线后 controller）.
  void dispose() {
    fade.dispose();
    layerEase.dispose();
    layerController.dispose();
    fadeController.dispose();
  }
}
