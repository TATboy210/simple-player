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

  /// 错误结构化上下文 — 携带错误发生时的环境信息 (D1)
  ///
  /// Optional for backward compatibility — existing catch sites that
  /// construct errors without context continue to work.
  ErrorContext? get context;

  /// 可变 context setter — 支持 FvpEngine 对 MediaOpener 错误的上下文丰富
  ///
  /// Used when engine enriches errors from lower layers (e.g., MediaOpener)
  /// with additional context like generation number.
  set context(ErrorContext? value);

  /// 是否为致命错误（不可恢复）
  ///
  /// Delegates to `!code.recoverable` for subclasses with code enums.
  /// `UnknownError` always returns false (always recoverable).
  bool get isFatal;

  /// UI 翻译键 — ErrorBanner 用此键查找 AppLocalizations (D7)
  ///
  /// Format: `error.{type}.{code}` (e.g., `error.file.fileNotFound`).
  /// `UnknownError` returns `'error.unknown'`.
  String get l10nKey;

  PlayerError();
}

/// 错误结构化上下文 — 携带错误发生时的环境信息 (D1)
///
/// Carries structured context at error construction site.
/// Fields are optional except timestamp (always set at construction).
/// Serialized via [toMap] for KernelLogger integration.
class ErrorContext {
  /// 操作名称 (e.g., 'open', 'play', 'seek')
  final String? action;

  /// open() 递增计数器 — 关联到具体哪次 open 请求
  final int? generation;

  /// 文件路径或 URL
  final String? path;

  /// 错误发生时间 (D3: default DateTime.now(), injectable for tests)
  final DateTime timestamp;

  /// 模块名称 (e.g., 'FvpEngine', 'MediaOpener')
  final String? module;

  /// mdk 回调线程栈 — 仅跨线程封送时填充 (D11)
  final StackTrace? callbackStackTrace;

  ErrorContext({
    this.action,
    this.generation,
    this.path,
    DateTime? timestamp,
    this.module,
    this.callbackStackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 序列化为 Map — 传给 KernelLogger.error(context:) 参数
  Map<String, Object?> toMap() => {
    if (action != null) 'action': action,
    if (generation != null) 'generation': generation,
    if (path != null) 'path': path,
    'timestamp': timestamp.toIso8601String(),
    if (module != null) 'module': module,
    if (callbackStackTrace != null)
      'callbackStackTrace': callbackStackTrace.toString(),
  };
}

// ── 文件错误 ──

/// 文件相关错误（路径、存在性、安全性）
final class FileError extends PlayerError {
  /// 错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
  final FileErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  @override
  ErrorContext? context;

  FileError(this.code, this.message, [this.cause, this.context]);

  @override
  bool get isFatal => !code.recoverable;

  @override
  String get l10nKey => 'error.file.${code.name}';

  @override
  String toString() => 'FileError(${code.name}): $message';
}

/// 文件错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
enum FileErrorCode {
  /// 路径为空 — 可恢复
  pathEmpty(recoverable: true),

  /// 文件不存在 — 可恢复
  fileNotFound(recoverable: true),

  /// 路径遍历攻击（../、null byte、UNC）— 致命
  pathTraversal(recoverable: false);

  /// Whether this error code is recoverable (non-fatal)
  final bool recoverable;
  const FileErrorCode({required this.recoverable});
}

// ── 编解码错误 ──

/// 编解码/格式相关错误
final class CodecError extends PlayerError {
  /// 错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
  final CodecErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  @override
  ErrorContext? context;

  CodecError(this.code, this.message, [this.cause, this.context]);

  @override
  bool get isFatal => !code.recoverable;

  @override
  String get l10nKey => 'error.codec.${code.name}';

  @override
  String toString() => 'CodecError(${code.name}): $message';
}

/// 编解码错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
enum CodecErrorCode {
  /// 不支持的媒体格式 — 可恢复
  unsupportedFormat(recoverable: true),

  /// 解码失败 — 可恢复
  decodeFailed(recoverable: true),

  /// 编解码器不支持 — 可恢复
  codecUnsupported(recoverable: true);

  /// Whether this error code is recoverable (non-fatal)
  final bool recoverable;
  const CodecErrorCode({required this.recoverable});
}

// ── 播放错误 ──

/// 播放控制相关错误
final class PlaybackError extends PlayerError {
  /// 错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
  final PlaybackErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  @override
  ErrorContext? context;

  PlaybackError(this.code, this.message, [this.cause, this.context]);

  @override
  bool get isFatal => !code.recoverable;

  @override
  String get l10nKey => 'error.playback.${code.name}';

  @override
  String toString() => 'PlaybackError(${code.name}): $message';
}

/// 播放错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
enum PlaybackErrorCode {
  /// 播放失败 — 可恢复
  playFailed(recoverable: true),

  /// 跳转失败 — 可恢复
  seekFailed(recoverable: true),

  /// 纹理创建失败 — 致命
  textureFailed(recoverable: false),

  /// 打开超时 — 可恢复
  openTimeout(recoverable: true);

  /// Whether this error code is recoverable (non-fatal)
  final bool recoverable;
  const PlaybackErrorCode({required this.recoverable});
}

// ── 网络错误 ──

/// 网络相关错误
final class NetworkError extends PlayerError {
  /// 错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
  final NetworkErrorCode code;

  @override
  final String message;

  @override
  final Object? cause;

  @override
  ErrorContext? context;

  NetworkError(this.code, this.message, [this.cause, this.context]);

  @override
  bool get isFatal => !code.recoverable;

  @override
  String get l10nKey => 'error.network.${code.name}';

  @override
  String toString() => 'NetworkError(${code.name}): $message';
}

/// 网络错误码注册表 — append-only, 现有码永不重命名/删除 (D6)
enum NetworkErrorCode {
  /// 网络超时 — 可恢复
  timeout(recoverable: true),

  /// 连接丢失 — 可恢复
  connectionLost(recoverable: true);

  /// Whether this error code is recoverable (non-fatal)
  final bool recoverable;
  const NetworkErrorCode({required this.recoverable});
}

// ── 未知错误 ──

/// 未分类错误 — 始终可恢复 (research Open Q4)
final class UnknownError extends PlayerError {
  @override
  final String message;

  @override
  final Object? cause;

  @override
  ErrorContext? context;

  UnknownError(this.message, [this.cause, this.context]);

  /// UnknownError 始终可恢复 — 未分类不代表致命
  @override
  bool get isFatal => false;

  @override
  String get l10nKey => 'error.unknown';

  @override
  String toString() => 'UnknownError: $message';
}
