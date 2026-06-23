import 'package:player_engine/player_engine.dart';

/// 媒体打开结果 — sealed class 表示成功或失败
sealed class OpenResult {
  const OpenResult();

  /// 成功打开
  static const success = OpenSuccess();
}

/// 打开成功
final class OpenSuccess extends OpenResult {
  const OpenSuccess();
}

/// 打开失败
final class OpenError extends OpenResult {
  final MediaErrorType type;
  final String message;

  const OpenError(this.type, this.message);
}
