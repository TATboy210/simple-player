/// 状态转换结果枚举 — 替代 bool 返回值
///
/// State transition result enum — replaces bool return type.
///
/// 由 [EngineStateMachine.transitionTo] 返回，提供三态语义：
/// - [ok] 转换成功
/// - [illegal] 非法转换（违反状态矩阵），已通过 KernelLogger.warn 记录
/// - [staleGeneration] generation 过期（open 请求已被新请求取代）
///
/// Returned by [EngineStateMachine.transitionTo] with three-state semantics:
/// - [ok] transition succeeded
/// - [illegal] illegal transition (violates state matrix), logged via KernelLogger.warn
/// - [staleGeneration] generation expired (open request superseded by newer request)
enum TransitionResult {
  /// 转换成功 — 状态已更新
  ///
  /// Transition succeeded — state has been updated.
  ok,

  /// 非法转换 — 违反状态矩阵，被拒绝
  ///
  /// Illegal transition — violates state matrix, rejected.
  /// Logged via KernelLogger.warn in all build modes (not assert-only).
  illegal,

  /// generation 过期 — 请求已被新请求取代
  ///
  /// Stale generation — request superseded by a newer open() call.
  /// The transition is rejected to prevent stale callbacks from corrupting state.
  staleGeneration,
}
