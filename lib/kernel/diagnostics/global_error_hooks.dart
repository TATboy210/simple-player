/// Thin synchronous adapters from Flutter's global error boundaries to reports.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'error_reporter.dart';
import 'error_reporting_dependencies.dart';

/// Callback shape assigned to [FlutterError.onError].
typedef FlutterErrorHandlerSetter =
    void Function(FlutterExceptionHandler? callback);

/// Root-isolate callback shape assigned to [PlatformDispatcher.onError].
typedef PlatformErrorCallback =
    bool Function(Object error, StackTrace stackTrace);

/// Callback setter seam for [PlatformDispatcher.onError].
typedef PlatformErrorHandlerSetter =
    void Function(PlatformErrorCallback? callback);

/// Framework diagnostic presentation seam.
typedef FrameworkErrorPresentation = void Function(FlutterErrorDetails details);

/// 三个全局 Flutter/Dart 错误边界的同步适配器。
///
/// Installs lightweight callbacks that preserve framework diagnostics before
/// forwarding opaque inputs into the reporter. Each callback is a containment
/// boundary: diagnostic failures use [LastResortOutput] and never escape.
final class GlobalErrorHooks {
  /// Creates production global-hook adapters.
  GlobalErrorHooks()
    : _setFrameworkErrorHandler = _setProductionFrameworkErrorHandler,
      _setPlatformErrorHandler = _setProductionPlatformErrorHandler,
      _presentFrameworkError = FlutterError.presentError,
      _lastResortOutput = _defaultLastResortOutput;

  /// Creates callback seams for deterministic tests without global mutation.
  @visibleForTesting
  const GlobalErrorHooks.forTesting({
    required FlutterErrorHandlerSetter setFrameworkErrorHandler,
    required PlatformErrorHandlerSetter setPlatformErrorHandler,
    required FrameworkErrorPresentation presentFrameworkError,
    LastResortOutput lastResortOutput = _defaultLastResortOutput,
  }) : _setFrameworkErrorHandler = setFrameworkErrorHandler,
       _setPlatformErrorHandler = setPlatformErrorHandler,
       _presentFrameworkError = presentFrameworkError,
       _lastResortOutput = lastResortOutput;

  final FlutterErrorHandlerSetter _setFrameworkErrorHandler;
  final PlatformErrorHandlerSetter _setPlatformErrorHandler;
  final FrameworkErrorPresentation _presentFrameworkError;
  final LastResortOutput _lastResortOutput;

  /// Installs production process-global callbacks after reporter initialization.
  static void install(ErrorReporter reporter) {
    GlobalErrorHooks().installCallbacks(reporter);
  }

  /// Installs this instance's callback seams for production or tests.
  void installCallbacks(ErrorReporter reporter) {
    _setFrameworkErrorHandler((details) => _handleFramework(reporter, details));
    _setPlatformErrorHandler(
      (error, stackTrace) => _handlePlatform(reporter, error, stackTrace),
    );
  }

  void _handleFramework(ErrorReporter reporter, FlutterErrorDetails details) {
    try {
      // Retain Flutter's normal development presentation before app reporting.
      _presentFrameworkError(details);
    } on Object catch (failure, stackTrace) {
      _emitLastResort(failure, stackTrace);
    }
    try {
      reporter.reportFlutterSafely(details);
    } on Object catch (failure, stackTrace) {
      _emitLastResort(failure, stackTrace);
    }
  }

  bool _handlePlatform(
    ErrorReporter reporter,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      reporter.reportPlatformSafely(error, stackTrace);
    } on Object catch (failure, fallbackStackTrace) {
      _emitLastResort(failure, fallbackStackTrace);
    }
    return true;
  }

  void _emitLastResort(Object error, StackTrace stackTrace) {
    try {
      _lastResortOutput(error, stackTrace);
    } on Object {
      // The terminal fallback must not recurse into diagnostics.
    }
  }

  static void _setProductionFrameworkErrorHandler(
    FlutterExceptionHandler? callback,
  ) {
    FlutterError.onError = callback;
  }

  static void _setProductionPlatformErrorHandler(
    PlatformErrorCallback? callback,
  ) {
    PlatformDispatcher.instance.onError = callback;
  }

  static void _defaultLastResortOutput(Object error, StackTrace stackTrace) {
    // This adapter intentionally delegates final containment to the reporter's
    // production fallback instead of introducing logging or I/O in hooks.
  }
}
