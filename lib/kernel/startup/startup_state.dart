import 'package:flutter/foundation.dart';

/// 启动阶段枚举
enum StartupPhase {
  /// Flutter 绑定初始化
  binding,

  /// 基础设施并行启动（Rust + SharedPreferences + WindowService）
  infrastructure,

  /// 设置加载（locale/theme）
  settings,

  /// 播放器模块延迟加载
  playerModule,

  /// 播放器服务初始化（Engine + Playlist + Controller）
  playerInit,

  /// 全部就绪
  ready,
}

/// 启动状态 — 不可变值对象
///
/// 由 [StartupCoordinator] 持有并通过 ValueNotifier 广播。
/// UI 层通过 `ValueListenableBuilder<StartupState>` 监听。
@immutable
class StartupState {
  const StartupState({
    this.phase = StartupPhase.binding,
    this.progress = 0.0,
    this.message = '',
  });

  static const initial = StartupState();

  final StartupPhase phase;

  /// 0.0 ~ 1.0 的启动进度
  final double progress;

  /// 当前阶段的描述文本（用于 UI 显示）
  final String message;

  StartupState copyWith({
    StartupPhase? phase,
    double? progress,
    String? message,
  }) => StartupState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    message: message ?? this.message,
  );

  bool get isReady => phase == StartupPhase.ready;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StartupState &&
          phase == other.phase &&
          progress == other.progress &&
          message == other.message;

  @override
  int get hashCode => Object.hash(phase, progress, message);
}
