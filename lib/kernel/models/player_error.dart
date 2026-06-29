/// 播放器错误码
///
/// 覆盖文件打开、解码、网络、纹理等全链路错误类型。
/// UI 层可据此显示精确提示，而非解析字符串。
enum PlayerErrorCode {
  /// 路径为空
  pathEmpty,

  /// 文件不存在
  fileNotFound,

  /// 路径遍历攻击（../、null byte、UNC）
  pathTraversal,

  /// 不支持的媒体格式
  unsupportedFormat,

  /// 媒体准备超时
  openTimeout,

  /// 解码失败
  decodeFailed,

  /// 纹理创建失败
  textureFailed,

  /// 网络超时
  networkTimeout,

  /// 编解码器不支持
  codecUnsupported,

  /// 文件损坏
  fileCorruption,

  /// 未知错误
  unknown,
}

/// 播放器结构化错误
///
/// 替代纯字符串 errorMessage，携带错误码 + 人类可读消息 + 原始异常。
/// 通过 EngineState.errorStream 传递，UI 层可监听并展示精准提示。
class PlayerError {
  final PlayerErrorCode code;
  final String message;
  final Object? cause;

  const PlayerError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'PlayerError(${code.name}): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerError && code == other.code && message == other.message;

  @override
  int get hashCode => code.hashCode ^ message.hashCode;
}
