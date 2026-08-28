/// PlayerError 生产入口桥 — 汇合 controller callback 与 engine notifier。
///
/// Owns exactly one project-level listener and forwards immutable snapshots to
/// [ErrorReporter] without coupling diagnostics to MediaKitEngine.
library;

import '../engine/media_engine.dart';
import '../models/player_error.dart';
import 'error_reporter.dart';
import 'error_reporting_dependencies.dart';

/// Connects project-owned player error surfaces to the unified reporter.
final class PlayerErrorReportBridge {
  /// Creates the bridge and subscribes only to [MediaEngine.lastError].
  PlayerErrorReportBridge({
    required MediaEngine engine,
    required ErrorReporter reporter,
    required CurrentMediaPathProvider currentMediaPath,
  }) : _engine = engine,
       _reporter = reporter,
       _currentMediaPath = currentMediaPath {
    _engine.lastError.addListener(_onEngineError);
  }

  final MediaEngine _engine;
  final ErrorReporter _reporter;
  final CurrentMediaPathProvider _currentMediaPath;
  PlayerError? _lastForwardedEngineError;
  bool _isDisposed = false;

  /// Controller callback injected by the composition root.
  void reportControllerError(PlayerError error) {
    if (_isDisposed || identical(error, _lastForwardedEngineError)) return;
    _reportSafely(error);
  }

  /// Removes the exact notifier listener; repeated teardown is safe.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _engine.lastError.removeListener(_onEngineError);
  }

  /// Forwards engine-originated errors and remembers their exact identity.
  void _onEngineError() {
    if (_isDisposed) return;
    final error = _engine.lastError.value;
    if (error == null) return;
    _lastForwardedEngineError = error;
    _reportSafely(error);
  }

  /// Contains untrusted error access so diagnostic intake never changes playback.
  void _reportSafely(PlayerError error) {
    final mediaPath = _snapshotMediaPath(error);
    try {
      _reporter.reportPlayerError(error, mediaPath: mediaPath);
    } on Object {
      // The reporter has its own terminal fallback; bridge intake stays inert.
    }
  }

  /// Captures optional metadata without allowing its failure to drop evidence.
  String? _snapshotMediaPath(PlayerError error) {
    try {
      return error.context?.path ?? _currentMediaPath();
    } on Object {
      // This external callback boundary may throw; the player event is required.
      return null;
    }
  }
}
