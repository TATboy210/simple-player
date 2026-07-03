import 'dart:async';

/// 播放器错误事件基类
sealed class PlayerError {
  const PlayerError(this.message, [this.cause]);
  final String message;
  final Object? cause;
}

/// 引擎播放错误
class PlaybackError extends PlayerError {
  const PlaybackError(super.message, [super.cause]);
}

/// 路径校验错误
class ValidationError extends PlayerError {
  const ValidationError(super.message, [super.cause]);
}

/// 字幕加载错误
class SubtitleError extends PlayerError {
  const SubtitleError(super.message, [super.cause]);
}

/// 统一错误总线 — 所有播放器错误的广播通道
///
/// UI 层通过 [errors] 监听，业务层通过 [emit] 发送。
class PlayerErrorBus {
  final _controller = StreamController<PlayerError>.broadcast();

  /// 错误事件流
  Stream<PlayerError> get errors => _controller.stream;

  /// 发送错误事件
  void emit(PlayerError error) {
    if (!_controller.isClosed) {
      _controller.add(error);
    }
  }

  void dispose() {
    _controller.close();
  }
}
