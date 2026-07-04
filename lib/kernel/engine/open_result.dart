import 'media_error_type.dart';
import 'models/media_info.dart';

/// Result of opening a media file — sealed for exhaustive pattern matching.
///
/// Dart 3 sealed class ensures all cases are handled in switch expressions:
/// ```dart
/// switch (result) {
///   case OpenSuccess(:final mediaInfo) => // use mediaInfo
///   case OpenError(:final type, :final message) => // show error
/// }
/// ```
sealed class OpenResult {
  const OpenResult();
}

/// Opening succeeded — carries parsed media metadata.
final class OpenSuccess extends OpenResult {
  /// Parsed media info (codec, resolution, duration, tracks).
  final MediaInfo mediaInfo;
  const OpenSuccess(this.mediaInfo);
}

/// Opening failed — carries error category and human-readable message.
final class OpenError extends OpenResult {
  /// Error category (fileNotFound, unsupportedFormat, etc.) for programmatic handling.
  final MediaErrorType type;

  /// Human-readable error description for UI display.
  final String message;

  const OpenError(this.type, this.message);
}
