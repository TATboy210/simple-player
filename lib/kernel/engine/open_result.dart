import 'package:player_engine/player_engine.dart';

/// 媒体打开结果 — sealed class 表示成功或失败
sealed class OpenResult {
  const OpenResult();
}

/// 打开成功 — 携带解析后的 MediaInfo
final class OpenSuccess extends OpenResult {
  final MediaInfo mediaInfo;
  const OpenSuccess(this.mediaInfo);
}

/// 打开失败
final class OpenError extends OpenResult {
  final MediaErrorType type;
  final String message;

  const OpenError(this.type, this.message);
}
