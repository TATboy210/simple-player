/// Services 层错误总线模块 — sealed class 层次结构 + 广播流分发
///
/// 本文件实现 [PlayerErrorBus] 集中式错误分发通道和 [PlayerError] sealed class 层次结构。
/// 业务层通过 emit() 发送错误，UI 层通过 errors 监听并处理。
///
/// 架构位置：PlaybackController / PlaybackNavigator / FileOperations → **PlayerErrorBus** → UI 层
/// 设计模式：Event Bus（事件总线）— 集中式错误分发，替代 try-catch 逐层传播
/// sealed class 好处：UI 层 switch 表达式可穷尽所有错误类型，编译器检查是否遗漏
library;

import 'dart:async';

/// 播放器错误事件基类 — sealed class 确保 exhaustive switch
///
/// 所有播放器错误都继承自此密封类，UI 层可通过 switch 表达式
/// 安全地处理每种错误类型，编译器会检查是否遗漏。
sealed class PlayerError {
  const PlayerError(this.message, [this.cause]);

  /// 错误描述信息
  final String message;

  /// 原始异常（可选）— 保留底层错误上下文
  final Object? cause;
}

/// 引擎播放错误 — open/play/seek 等操作失败时抛出
class PlaybackError extends PlayerError {
  const PlaybackError(super.message, [super.cause]);
}

/// 路径校验错误 — PathValidator 检测到不安全路径时抛出
class ValidationError extends PlayerError {
  const ValidationError(super.message, [super.cause]);
}

/// 字幕加载错误 — SubtitleService 检测或加载字幕失败时抛出
class SubtitleError extends PlayerError {
  const SubtitleError(super.message, [super.cause]);
}

/// 统一错误总线 — 所有播放器错误的广播通道
///
/// 使用 StreamController.broadcast() 实现多监听器模式，
/// UI 层多个组件可同时监听同一条错误流。
///
/// 使用方式：
/// - 业务层：`errorBus.emit(PlaybackError('打开失败', e))`
/// - UI 层：`errorBus.errors.listen((error) { switch (error) { ... } })`
class PlayerErrorBus {
  final _controller = StreamController<PlayerError>.broadcast();

  /// 错误事件流 — UI 层通过此监听所有播放器错误
  Stream<PlayerError> get errors => _controller.stream;

  /// 发送错误事件 — 业务层调用此方法触发错误通知
  ///
  /// 如果流已关闭（dispose 后），静默忽略（避免 late listener 异常）。
  void emit(PlayerError error) {
    if (!_controller.isClosed) {
      _controller.add(error);
    }
  }

  /// 关闭错误总线 — 释放 StreamController 资源
  void dispose() {
    _controller.close();
  }
}
