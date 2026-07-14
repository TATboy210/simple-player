/// 播放器结构化错误 — sealed class 层级
///
/// 替代旧的 flat enum + class 组合，支持穷举模式匹配。
/// 每个子类型携带自己的子枚举 code，兼顾类型安全和细粒度错误码。
///
/// ```dart
/// switch (error) {
///   case FileError(:final code) => // 处理文件错误
///   case CodecError(:final code) => // 处理解码错误
///   case PlaybackError(:final code) => // 处理播放错误
///   case NetworkError(:final code) => // 处理网络错误
///   case UnknownError(:final message) => // 处理未知错误
/// }
/// ```
sealed class PlayerError {
  /// 人类可读的错误消息
  String get message;

  /// 原始异常（可选）
  Object? get cause;

  const PlayerError();
}

// ── 文件错误 ──

/// 文件相关错误（路径、存在性、安全性）
final class FileError extends PlayerError {
  final FileErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  const FileError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'FileError(${code.name}): $message';
}

enum FileErrorCode {
  /// 路径为空
  pathEmpty,

  /// 文件不存在
  fileNotFound,

  /// 路径遍历攻击（../、null byte、UNC）
  pathTraversal,
}

// ── 编解码错误 ──

/// 编解码/格式相关错误
final class CodecError extends PlayerError {
  final CodecErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  const CodecError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'CodecError(${code.name}): $message';
}

enum CodecErrorCode {
  /// 不支持的媒体格式
  unsupportedFormat,

  /// 解码失败
  decodeFailed,

  /// 编解码器不支持
  codecUnsupported,
}

// ── 播放错误 ──

/// 播放控制相关错误
final class PlaybackError extends PlayerError {
  final PlaybackErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  const PlaybackError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'PlaybackError(${code.name}): $message';
}

enum PlaybackErrorCode {
  /// 播放失败
  playFailed,

  /// 跳转失败
  seekFailed,

  /// 纹理创建失败
  textureFailed,

  /// 打开超时
  openTimeout,
}

// ── 网络错误 ──

/// 网络相关错误
final class NetworkError extends PlayerError {
  final NetworkErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  const NetworkError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'NetworkError(${code.name}): $message';
}

enum NetworkErrorCode {
  /// 网络超时
  timeout,

  /// 连接丢失
  connectionLost,
}

// ── 未知错误 ──

/// 未分类错误
final class UnknownError extends PlayerError {
  @override
  final String message;

  @override
  final Object? cause;

  const UnknownError(this.message, [this.cause]);

  @override
  String toString() => 'UnknownError: $message';
}
