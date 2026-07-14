import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/kernel/engine/models/media_info.dart';

/// 打开媒体文件的结果 — sealed for exhaustive pattern matching.
///
/// Dart 3 sealed class 确保 switch 表达式穷举所有情况：
/// ```dart
/// switch (result) {
///   case OpenSuccess(:final mediaInfo) => // 使用 mediaInfo
///   case OpenError(:final error) => // 通过 error 的 sealed 子类型匹配
///     switch (error) {
///       case FileError(:final code) => // 文件错误
///       case CodecError(:final code) => // 编解码错误
///       case PlaybackError(:final code) => // 播放错误
///       case NetworkError(:final code) => // 网络错误
///       case UnknownError(:final message) => // 未知错误
///     }
/// }
/// ```
sealed class OpenResult {
  const OpenResult();
}

/// 打开成功 — 携带解析后的媒体元信息。
final class OpenSuccess extends OpenResult {
  /// 解析后的媒体信息（编解码、分辨率、时长、轨道）。
  final MediaInfo mediaInfo;
  const OpenSuccess(this.mediaInfo);
}

/// 打开失败 — 携带结构化错误信息。
final class OpenError extends OpenResult {
  /// 结构化错误 — 支持穷举模式匹配。
  final PlayerError error;

  const OpenError(this.error);

  /// 便捷访问错误消息
  String get message => error.message;
}
