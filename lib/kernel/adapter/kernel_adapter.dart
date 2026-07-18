/// 单一仲裁枚举 — 标识某能力路由到旧引擎还是新引擎 (D14/ADAPT-04).
///
/// Single arbiter enum: per-capability routing target. Phase 16 uses
/// `KernelMode.legacy` exclusively via `DelegationPolicy.all(KernelMode.legacy)`.
enum KernelMode { legacy, migrated }

/// 委托策略 — 7 个 final KernelMode 字段, 一一对应 MediaEngine 的 7 个 ISP 子接口 (D14).
///
/// Immutable per-capability routing policy. All 7 fields are `final` (D15):
/// cutover rebuilds the adapter rather than flipping in place — this is the
/// structural protection for Blocking Constraint #6 (identity-preserving
/// ValueNotifier forwarding; a mid-flight policy flip would detach UI
/// listeners). `stateView` is a plain field with no extra pin/factory
/// constraint (D18): the final+recreate guarantee already bounds its mutation,
/// and an additional pin would be redundant over-engineering that also
/// blocks Phase 20's partial cutover.
final class DelegationPolicy {
  const DelegationPolicy({
    required this.stateView,
    required this.playback,
    required this.track,
    required this.subtitle,
    required this.videoEffect,
    required this.renderer,
    required this.volume,
  });

  /// 全部 7 能力路由到同一 KernelMode — Phase 16 仅使用
  /// `DelegationPolicy.all(KernelMode.legacy)` (D14).
  ///
  /// All 7 capabilities routed to the same [KernelMode]. Phase 16 uses
  /// `DelegationPolicy.all(KernelMode.legacy)` exclusively (D14).
  const DelegationPolicy.all(KernelMode mode)
      : stateView = mode,
        playback = mode,
        track = mode,
        subtitle = mode,
        videoEffect = mode,
        renderer = mode,
        volume = mode;

  /// EngineStateView 子接口路由 (只读状态视图, 11 ValueNotifier + mediaInfo).
  final KernelMode stateView;

  /// PlaybackControl 子接口路由 (open/play/pause/seek 等控制方法).
  final KernelMode playback;

  /// TrackControl 子接口路由 (音轨查询/切换).
  final KernelMode track;

  /// SubtitleConfig 子接口路由 (字幕轨道/延迟/均衡器).
  final KernelMode subtitle;

  /// VideoEffectControl 子接口路由 (亮度/旋转/宽高比/反交错).
  final KernelMode videoEffect;

  /// RendererControl 子接口路由 (D3D11 同步/硬解).
  final KernelMode renderer;

  /// VolumeControl 子接口路由 (音量/静音 — 单一路由, 见 KernelAdapter).
  final KernelMode volume;
}
