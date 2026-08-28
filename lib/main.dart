import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/error_reporter.dart';
import 'kernel/diagnostics/error_reporting_dependencies.dart';
import 'kernel/diagnostics/global_error_hooks.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';

/// 应用组合根：在同一 guarded zone 内初始化并启动应用。
///
/// The zone encloses binding creation, diagnostic setup, global callbacks, and
/// every bootstrap await so callback registration remains in the app's zone.
Future<void> main() {
  return runZonedGuarded<Future<void>>(() async {
        if (kDebugMode) {
          MarionetteBinding.ensureInitialized();
        } else {
          WidgetsFlutterBinding.ensureInitialized();
        }

        KernelLoggerImpl.init();
        ErrorReporterImpl.init();
        GlobalErrorHooks.install(ErrorReporterImpl.I);
        MediaKit.ensureInitialized();
        await windowManager.ensureInitialized();

        // 启动时序诊断 — 打点式纯计时器，无 UI 广播职责（见 StartupTimeline 注释）。
        final startupTimeline = StartupTimeline();
        final windowService = WindowService();
        String? windowInitError;
        try {
          await windowService.init();
          startupTimeline.mark(StartupTimeline.phaseInfrastructure);
        } on Object catch (error, stackTrace) {
          // Preserve the App-facing state while recording this handled failure once.
          windowInitError = '$error';
          KernelLogger.I.e(
            '[main] Window initialization failed: $error',
            error: error,
            stackTrace: stackTrace,
          );
          ErrorReporterImpl.I.reportBootstrapSafely(error, stackTrace);
        }

        runApp(
          App(
            startupTimeline: startupTimeline,
            windowService: windowService,
            windowInitError: windowInitError,
          ),
        );
      }, BootstrapErrorFallback.report) ??
      Future<void>.value();
}

/// 启动期 zone 错误的独立、非递归兜底。
///
/// Delegates only when the reporter lifecycle probe confirms singleton access
/// is safe. Otherwise it attempts one terminal output and always returns.
final class BootstrapErrorFallback {
  /// Handles a guarded-zone error with production singleton collaborators.
  static void report(Object error, StackTrace stackTrace) {
    reportWith(
      error,
      stackTrace,
      isReporterInitialized: () => ErrorReporterImpl.isInitialized,
      reportInitialized: (failure, trace) =>
          ErrorReporterImpl.I.reportBootstrapSafely(failure, trace),
      lastResortOutput: _defaultLastResortOutput,
    );
  }

  /// Executes the fallback with injected lifecycle seams for deterministic tests.
  @visibleForTesting
  static void reportWith(
    Object error,
    StackTrace stackTrace, {
    required bool Function() isReporterInitialized,
    required LastResortOutput reportInitialized,
    required LastResortOutput lastResortOutput,
  }) {
    try {
      if (isReporterInitialized()) {
        try {
          reportInitialized(error, stackTrace);
          return;
        } on Object catch (failure, fallbackStackTrace) {
          _emitLastResort(lastResortOutput, failure, fallbackStackTrace);
          return;
        }
      }
    } on Object catch (failure, fallbackStackTrace) {
      _emitLastResort(lastResortOutput, failure, fallbackStackTrace);
      return;
    }
    _emitLastResort(lastResortOutput, error, stackTrace);
  }

  static void _emitLastResort(
    LastResortOutput lastResortOutput,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      lastResortOutput(error, stackTrace);
    } on Object {
      // Terminal containment: no reporter, logger, UI, or retry may follow.
    }
  }

  static void _defaultLastResortOutput(Object error, StackTrace stackTrace) {
    try {
      developer.log('Bootstrap error fallback: $error', stackTrace: stackTrace);
    } on Object {
      // A failing terminal output is intentionally ignored to avoid recursion.
    }
  }
}
