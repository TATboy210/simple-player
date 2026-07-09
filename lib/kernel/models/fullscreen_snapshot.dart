import 'fullscreen_error.dart';

/// 全屏过渡阶段 — 状态机核心。
///
/// 转换路径: stable ↔ entering/leaving, stable → forcedChange → stable,
/// 任意状态 → error → stable (下次合法操作自动清理)
enum FullscreenPhase {
  /// 稳态 — 无进行中的过渡。
  stable,

  /// 正在进入全屏。
  entering,

  /// 正在退出全屏。
  leaving,

  /// OS 外部强制变更（如系统快捷键、窗口管理器）。
  forcedChange,

  /// 上次操作出错 — 下次合法操作自动清理。
  error,
}

/// 全屏模式 — 区分普通全屏和独占全屏。
enum FullscreenMode {
  /// 非全屏。
  windowed,

  /// 无边框全屏（当前实现）。
  borderless,

  /// 独占全屏（预留 v2）。
  exclusive,
}

/// 全屏状态快照 — 单一 ValueNotifier 包装的不可变数据。
///
/// 设计约束:
/// - 纯数据类，不含业务逻辑
/// - 不可变（final class + final fields）
/// - copyWith 返回新实例
/// - 与 WindowState 独立共存，渐进迁移
final class FullscreenSnapshot {
  const FullscreenSnapshot({
    this.phase = FullscreenPhase.stable,
    this.effectiveMode = FullscreenMode.windowed,
    this.restoreMode = FullscreenMode.windowed,
    this.displayId = 0,
    this.lastError,
  });

  /// 当前过渡阶段。
  final FullscreenPhase phase;

  /// 实际生效的全屏模式。
  final FullscreenMode effectiveMode;

  /// 全屏前的窗口模式 — 退出时恢复目标。
  final FullscreenMode restoreMode;

  /// 当前显示器 ID（多显示器预留）。
  final int displayId;

  /// 最近一次错误（error phase 时非 null）。
  final FullscreenError? lastError;

  /// 是否处于稳定全屏状态。
  ///
  /// 仅在 phase == stable 且 effectiveMode 非 windowed 时返回 true。
  /// 过渡中（entering/leaving）不算全屏。
  bool get isFullscreen =>
      phase == FullscreenPhase.stable &&
      effectiveMode != FullscreenMode.windowed;

  /// 是否正在过渡中。
  bool get isTransitioning =>
      phase == FullscreenPhase.entering ||
      phase == FullscreenPhase.leaving;

  /// 是否处于错误状态。
  bool get hasError => phase == FullscreenPhase.error;

  /// 创建副本 — 只修改指定字段。
  ///
  /// [clearError] 为 true 时将 lastError 设为 null（用于 error → stable 清理）。
  FullscreenSnapshot copyWith({
    FullscreenPhase? phase,
    FullscreenMode? effectiveMode,
    FullscreenMode? restoreMode,
    int? displayId,
    FullscreenError? lastError,
    bool clearError = false,
  }) {
    return FullscreenSnapshot(
      phase: phase ?? this.phase,
      effectiveMode: effectiveMode ?? this.effectiveMode,
      restoreMode: restoreMode ?? this.restoreMode,
      displayId: displayId ?? this.displayId,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FullscreenSnapshot &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          effectiveMode == other.effectiveMode &&
          restoreMode == other.restoreMode &&
          displayId == other.displayId &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
        phase,
        effectiveMode,
        restoreMode,
        displayId,
        lastError,
      );

  @override
  String toString() =>
      'FullscreenSnapshot(phase: $phase, mode: $effectiveMode, '
      'restore: $restoreMode, display: $displayId, error: $lastError)';
}
