/// Application Support default diagnostic log location resolver.
library;

import 'dart:io';

/// Asynchronous platform seam that resolves the application support directory.
typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();

/// Typed outcome for default diagnostic log target preparation.
sealed class ErrorLogLocationResult {
  const ErrorLogLocationResult();
}

/// Prepared default diagnostic log target under Application Support.
final class ErrorLogLocationResolved extends ErrorLogLocationResult {
  const ErrorLogLocationResolved(this.file);

  /// The prepared `logs/error.log` target.
  final File file;
}

/// Unavailable default target with its contained external failure reason.
final class ErrorLogLocationUnavailable extends ErrorLogLocationResult {
  const ErrorLogLocationUnavailable(this.error, this.stackTrace);

  /// Provider or filesystem failure retained only for contained bootstrap logging.
  final Object error;

  /// Stack evidence paired with [error] for a non-recursive warning.
  final StackTrace stackTrace;
}

/// Resolves the only production default: Application Support/logs/error.log.
///
/// The composition root supplies the platform provider, keeping plugin work out
/// of kernel static initialization. Any external failure becomes a typed result.
final class ErrorLogLocation {
  ErrorLogLocation._();

  /// Single source of truth for the default child directory.
  static const String logsDirectoryName = 'logs';

  /// Single source of truth for the default diagnostic filename.
  static const String logFileName = 'error.log';

  /// Creates the logs child before returning the fixed diagnostic log target.
  static Future<ErrorLogLocationResult> resolve({
    required ApplicationSupportDirectoryProvider applicationSupportDirectory,
  }) async {
    try {
      final supportDirectory = await applicationSupportDirectory();
      final logsDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}$logsDirectoryName',
      );
      // Side effect: this idempotently prepares the child before any file write.
      await logsDirectory.create(recursive: true);
      return ErrorLogLocationResolved(
        File('${logsDirectory.path}${Platform.pathSeparator}$logFileName'),
      );
    } on FileSystemException catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    } on IOException catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    }
  }
}
