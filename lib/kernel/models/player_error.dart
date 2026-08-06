import '../utils/path_utils.dart';

/// 播放器结构化错误 — sealed class 层级, 支持穷举模式匹配
///
/// Structured player error — sealed class hierarchy with exhaustive pattern matching.
/// 每个子类型携带自己的子枚举 code，兼顾类型安全和细粒度错误码。
/// Each subtype carries its own code enum for type-safe, fine-grained error codes.
///
/// ```dart
/// switch (error) {
///   case FileError(:final code) => // handle file error
///   case CodecError(:final code) => // handle codec error
///   case PlaybackError(:final code) => // handle playback error
///   case NetworkError(:final code) => // handle network error
///   case UnknownError(:final message) => // handle unknown error
/// }
/// ```
sealed class PlayerError {
  /// 人类可读的错误消息 — 用于日志和调试
  ///
  /// Human-readable error message — used for logging and debugging.
  String get message;

  /// 原始异常（可选）— 保留原始异常链用于调试
  ///
  /// Original exception (optional) — preserves exception chain for debugging.
  Object? get cause;

  /// 错误结构化上下文 — 携带错误发生时的环境信息 (D1), 可选以保持向后兼容
  ///
  /// Structured error context — carries environment info at error site.
  /// Optional for backward compatibility — existing catch sites that
  /// construct errors without context continue to work.
  ErrorContext? get context;

  /// 可变 context setter — 支持引擎对下层错误的上下文丰富
  ///
  /// Used when engine enriches errors from lower layers (e.g., media_kit Player)
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

/// 错误结构化上下文 — 携带错误发生时的环境信息, 用于日志关联和诊断 (D1)
///
/// Structured error context — carries environment info at error construction site.
/// Fields are optional except timestamp (always set at construction).
/// Serialized via [toMap] for KernelLogger integration.
class ErrorContext {
  /// 操作名称 (e.g., 'open', 'play', 'seek') — 用于日志关联
  ///
  /// Action name — used for log correlation and error categorization.
  final String? action;

  /// open() 递增计数器 — 关联到具体哪次 open 请求
  ///
  /// Open request generation counter — correlates error to specific open() call.
  final int? generation;

  /// 文件路径或 URL — 脱敏后用于日志
  ///
  /// File path or URL — redacted before logging.
  final String? path;

  /// 错误发生时间 — 默认 DateTime.now(), 测试可注入 (D3)
  ///
  /// Error timestamp — defaults to DateTime.now(), injectable for testing.
  final DateTime timestamp;

  /// 模块名称 (e.g., 'MediaKitEngine') — 标识错误来源
  ///
  /// Module name — identifies error source for diagnostics.
  final String? module;

  /// mdk 回调线程栈 — 仅跨线程封送时填充 (D11)
  ///
  /// mdk callback thread stack trace — populated only during cross-thread marshalling.
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
  ///
  /// 路径脱敏：只保留文件名，防止泄露用户目录结构
  Map<String, Object?> toMap() => {
    if (action != null) 'action': action,
    if (generation != null) 'generation': generation,
    if (path case final p?) 'path': PathUtils.basename(p),
    'timestamp': timestamp.toIso8601String(),
    if (module != null) 'module': module,
    if (callbackStackTrace != null)
      'callbackStackTrace': callbackStackTrace.toString(),
  };
}

// ── 文件错误 ──

/// 文件相关错误（路径、存在性、安全性）— 携带 FileErrorCode 子枚举
///
/// File-related errors (path, existence, security) — carries [FileErrorCode] sub-enum.
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
///
/// File error code registry — append-only, existing codes never renamed/deleted.
enum FileErrorCode {
  /// 路径为空 — 可恢复
  ///
  /// Path is empty — recoverable.
  pathEmpty(recoverable: true),

  /// 文件不存在 — 可恢复
  ///
  /// File not found — recoverable.
  fileNotFound(recoverable: true),

  /// 路径遍历攻击（../、null byte、UNC）— 致命
  ///
  /// Path traversal attack (../, null byte, UNC) — fatal.
  pathTraversal(recoverable: false);

  /// 是否可恢复（非致命）— recoverable 错误可被 UI 展示后继续使用
  ///
  /// Whether this error code is recoverable (non-fatal).
  /// Recoverable errors can be displayed and the player remains usable.
  final bool recoverable;
  const FileErrorCode({required this.recoverable});
}

// ── 编解码错误 ──

/// 编解码/格式相关错误 — 携带 CodecErrorCode 子枚举
///
/// Codec/format-related errors — carries [CodecErrorCode] sub-enum.
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
///
/// Codec error code registry — append-only, existing codes never renamed/deleted.
enum CodecErrorCode {
  /// 不支持的媒体格式 — 可恢复
  ///
  /// Unsupported media format — recoverable.
  unsupportedFormat(recoverable: true),

  /// 解码失败 — 可恢复
  ///
  /// Decode failed — recoverable.
  decodeFailed(recoverable: true),

  /// 编解码器不支持 — 可恢复
  ///
  /// Codec unsupported — recoverable.
  codecUnsupported(recoverable: true);

  /// 是否可恢复（非致命）
  ///
  /// Whether this error code is recoverable (non-fatal).
  final bool recoverable;
  const CodecErrorCode({required this.recoverable});
}

// ── 播放错误 ──

/// 播放控制相关错误 — 携带 PlaybackErrorCode 子枚举
///
/// Playback control errors — carries [PlaybackErrorCode] sub-enum.
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
///
/// Playback error code registry — append-only, existing codes never renamed/deleted.
enum PlaybackErrorCode {
  /// 播放失败 — 可恢复
  ///
  /// Playback failed — recoverable.
  playFailed(recoverable: true),

  /// 跳转失败 — 可恢复
  ///
  /// Seek failed — recoverable.
  seekFailed(recoverable: true),

  /// 纹理创建失败 — 致命 (GPU 资源不可用)
  ///
  /// Texture creation failed — fatal (GPU resource unavailable).
  textureFailed(recoverable: false),

  /// 打开超时 — 可恢复
  ///
  /// Open timeout — recoverable.
  openTimeout(recoverable: true);

  /// 是否可恢复（非致命）
  ///
  /// Whether this error code is recoverable (non-fatal).
  final bool recoverable;
  const PlaybackErrorCode({required this.recoverable});
}

// ── 网络错误 ──

/// 网络相关错误 — 携带 NetworkErrorCode 子枚举
///
/// Network-related errors — carries [NetworkErrorCode] sub-enum.
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
///
/// Network error code registry — append-only, existing codes never renamed/deleted.
enum NetworkErrorCode {
  /// 网络超时 — 可恢复
  ///
  /// Network timeout — recoverable.
  timeout(recoverable: true),

  /// 连接丢失 — 可恢复
  ///
  /// Connection lost — recoverable.
  connectionLost(recoverable: true);

  /// 是否可恢复（非致命）
  ///
  /// Whether this error code is recoverable (non-fatal).
  final bool recoverable;
  const NetworkErrorCode({required this.recoverable});
}

// ── 未知错误 ──

/// 未分类错误 — 始终可恢复, 未分类不代表致命 (research Open Q4)
///
/// Uncategorized error — always recoverable. Being uncategorized does not imply fatal.
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
