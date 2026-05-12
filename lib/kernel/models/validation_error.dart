/// 路径校验错误类型
enum ValidationErrorType {
  /// 路径为空
  empty,

  /// 路径遍历攻击（../、null byte、UNC、~）
  pathTraversal,

  /// 不支持的文件格式
  unsupportedFormat,

  /// URL 格式无效
  invalidUrl,

  /// 路径无效（文件系统错误）
  invalidPath,
}

/// 路径校验结构化错误
///
/// 替代纯字符串校验错误，携带错误类型枚举。
/// UI 层可据此显示精准提示。
class ValidationError {
  final ValidationErrorType type;
  final String message;

  const ValidationError(this.type, this.message);

  @override
  String toString() => 'ValidationError(${type.name}): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError &&
          type == other.type &&
          message == other.message;

  @override
  int get hashCode => type.hashCode ^ message.hashCode;
}
