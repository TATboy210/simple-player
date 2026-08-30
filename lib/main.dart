import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/error_log_file_sink.dart';
import 'kernel/diagnostics/error_log_location.dart';
import 'kernel/diagnostics/error_reporter.dart';
import 'kernel/diagnostics/error_reporting_dependencies.dart';
import 'kernel/diagnostics/global_error_hooks.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';

/// UAT Test 16 故障注入开关 — 仅当
/// `--dart-define=UAT_FAULT_WINDOW_INIT=true` 时启用，模拟 windowService.init()
/// 平台通道故障。生产构建默认 false，无任何行为变化。
const uatFaultWindowInit = bool.fromEnvironment('UAT_FAULT_WINDOW_INIT');

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
        // Install capture before any platform path or directory I/O can fail or stall.
        final diagnosticLogEffect = DelegatingDiagnosticLogEffect();
        ErrorReporterImpl.init(
          effects: [diagnosticLogEffect.record],
          diagnosticLogStatus: diagnosticLogEffect,
        );
        GlobalErrorHooks.install(ErrorReporterImpl.I);
        unawaited(_activateDiagnosticLog(diagnosticLogEffect));
        MediaKit.ensureInitialized();
        await windowManager.ensureInitialized();

        // 启动时序诊断 — 打点式纯计时器，无 UI 广播职责（见 StartupTimeline 注释）。
        final startupTimeline = StartupTimeline();
        final windowService = WindowService();
        String? windowInitError;
        try {
          // 故障注入：在真正调用 init 前抛出，走同一 try/catch 容纳路径（UAT Test 16）。
          if (uatFaultWindowInit) {
            throw StateError(
              'UAT fault injection: windowService.init() faulted',
            );
          }
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

          // 降级可见性兜底：原生窗口的 show 由 WindowService.init 内部负责，
          // init 失败时窗口保持隐藏，降级文字态将对用户不可见（UAT Test 16
          // 首轮实测发现的"隐形孤儿进程"）。这里 best-effort 直接 show——
          // 窗口以系统默认标题栏形态出现（紧急态可接受），setPreventClose
          // 未生效故默认关闭行为可用。若 show 本身失败，仅记录、不再上抛，
          // 保证容纳路径本身不会制造新的未处理异常。
          try {
            await windowManager.show();
          } on Object catch (showError, showStack) {
            KernelLogger.I.w(
              '[main] Degraded window show failed: $showError',
              context: {'error': '$showError', 'stackTrace': '$showStack'},
            );
          }
        }

        // 故障注入模式下的可观察证据：打印待展示报告数，验证恰好一份入队。
        if (uatFaultWindowInit) {
          debugPrint(
            '[uat-window-init-fault] pendingCount='
            '${ErrorReporterImpl.I.presentation.value.pendingCount}',
          );
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

/// Resolves and activates durable diagnostic evidence after global capture is live.
///
/// This asynchronous side effect intentionally does not delay MediaKit, window,
/// or runApp. Its failure is reported only through KernelLogger to avoid reporter
/// reentrancy while the file effect is itself unavailable.
Future<void> _activateDiagnosticLog(
  DelegatingDiagnosticLogEffect diagnosticLogEffect,
) async {
  try {
    final result = await ErrorLogLocation.resolve(
      applicationSupportDirectory: getApplicationSupportDirectory,
    );
    switch (result) {
      case ErrorLogLocationResolved(:final file):
        final sink = ErrorLogFileSink(file: file);
        diagnosticLogEffect.activate(sink: sink, resolvedPath: file.path);
      case ErrorLogLocationUnavailable(:final error, :final stackTrace):
        KernelLogger.I.warn(
          'Diagnostic file evidence is unavailable during startup.',
          context: <String, Object?>{
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
    }
  } on Object catch (error, stackTrace) {
    KernelLogger.I.warn(
      'Diagnostic file activation failed.',
      context: <String, Object?>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );
  }
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
