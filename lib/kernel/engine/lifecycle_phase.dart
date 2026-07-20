/// 引擎生命周期阶段 — 正交于 MediaState 的独立维度
///
/// Engine lifecycle phase — orthogonal dimension independent of MediaState.
///
/// 与 MediaState 正交共存：`state` 表示播放行为状态，
/// `lifecyclePhase` 表示引擎对象的存活阶段。
///
/// Coexists orthogonally with MediaState: `state` tracks playback behavior,
/// `lifecyclePhase` tracks engine object liveness.
enum LifecyclePhase {
  /// 引擎存活 — 正常工作状态
  ///
  /// Engine is alive and operational.
  alive,

  /// 正在释放 — dispose 已启动但未完成
  ///
  /// Disposal in progress — dispose() initiated but not yet complete.
  disposing,

  /// 已释放 — dispose 完成，不可再使用
  ///
  /// Disposed — dispose() complete, engine must not be used.
  disposed,
}
