import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';
import 'package:simple_player_flutter/kernel/engine/media_engine.dart';

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

/// Strangler Fig seam — 临时路由层, 非永久架构层 (Phase 21 删除).
///
/// `KernelAdapter implements MediaEngine` 并将 7 个 ISP 子接口的约 44 个成员
/// 按 [_policy] 逐能力转发到 [_legacy] 或 [_migrated] 引擎. 组成:
///   - [_legacy]:    当前 FvpEngine (Phase 16 权威)
///   - [_migrated]:   未来 NewFvpEngine (Phase 20 切换目标)
///   - [_policy]:     DelegationPolicy — 逐能力路由仲裁
///   - [_bundle]:      DiagnosticsBundle — Phase 16 全 noop (D2/D3)
///
/// Phase 16 立场: 刻意死路由 — `DelegationPolicy.all(KernelMode.legacy)`
/// 将 100% 路由到 [_legacy], 行为与直接使用 FvpEngine 完全一致. 适配器
/// 不持有任何可变状态 (D17): 无计数器, 无迁移标志, 无缓存 — engine/policy/
/// bundle 均为注入依赖.
///
/// Strangler Fig seam — a transient routing layer, NOT a permanent
/// architectural layer. `KernelAdapter` implements `MediaEngine` and forwards
/// every one of the ~44 members across the 7 ISP sub-interfaces to a wrapped
/// `legacy` or `migrated` engine, selected per-capability by [_policy]. The
/// seam is collapsed/deleted in Phase 21 (see ROADMAP Phase 21 SC4/D16).
///
/// P20 migration checklist (forward-looking, NOT implemented in Phase 16):
///   - openGeneration unified counter migrates from legacy into adapter/tracker (STATE-02, D23a)
///   - DiagnosticsBundle activation: swap noop slots to real slots (D3 dead-code -> live, D23b)
///   - DelegationPolicy field flip: all-legacy -> per-capability migrated (D14/STATE-06, D23c)
class KernelAdapter implements MediaEngine {
  /// 构造函数 — 旧/新引擎 + 委托策略 + 诊断 bundle (默认 noop, D12).
  ///
  /// Engine/policy/bundle are injected dependencies (not mutable state, D17).
  /// `bundle` defaults to `const DiagnosticsBundle.noop()` so Phase 16
  /// callers can omit it (D12 constructor signature).
  KernelAdapter({
    required MediaEngine legacy,
    required MediaEngine migrated,
    required DelegationPolicy policy,
    DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
  })  : _legacy = legacy,
        _migrated = migrated,
        _policy = policy,
        _bundle = bundle;

  final MediaEngine _legacy;
  final MediaEngine _migrated;
  final DelegationPolicy _policy;
  final DiagnosticsBundle _bundle;

  /// 释放活动引擎并级联释放 bundle (D10). 路由由 _policy.stateView 决定,
  /// 无额外内部条件分支 (Phase 15 D8 — 无 _isMigrating 等内部标志分支).
  ///
  /// dispose forwards to the active engine (selected by [_policy].stateView)
  /// AND cascades to [_bundle].dispose() (D10). One policy-based dispatch,
  /// no further internal branching (Phase 15 D8).
  @override
  void dispose() {
    (_policy.stateView == KernelMode.legacy ? _legacy : _migrated).dispose();
    _bundle.dispose();
  }
}

