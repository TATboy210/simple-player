import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/dwm_capabilities.dart';
import 'kernel/diagnostics/error_log_location.dart';
import 'kernel/diagnostics/error_reporter.dart';
import 'kernel/diagnostics/error_reporting_dependencies.dart';
import 'kernel/diagnostics/global_error_hooks.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';
import 'ui/dialogs/settings/diagnostic_log_target.dart';
import 'ui/dialogs/settings/error_feedback_settings.dart';
import 'ui/player/error_capture_snapshot.dart';

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
        // 快照 effect（D-11）：错误卡片徽标轮览的呈现层有界快照数据源，
        // 经既有 effects 缝挂入 —— kernel 零改动（见 ErrorCaptureSnapshot 注释）。
        final diagnosticLogEffect = DelegatingDiagnosticLogEffect();
        ErrorReporterImpl.init(
          effects: [diagnosticLogEffect.record, ErrorCaptureSnapshot.I.record],
          diagnosticLogStatus: diagnosticLogEffect,
        );
        GlobalErrorHooks.install(ErrorReporterImpl.I);
        // 协调器同步 attach：先于任何激活路径（unawaited）与 runApp，协调器
        // 在应用任意 UI 交互前就绪；重复 attach 静默忽略由协调器承载。
        // 位置约束：必须位于 hooks 安装之后（hooks-first 契约测试锁定
        // 「首个平台目录引用不得先于 GlobalErrorHooks.install」），且在
        // _activateDiagnosticLog 启动之前完成绑定。
        DiagnosticLogTarget.I.attach(
          effect: diagnosticLogEffect,
          applicationSupportDirectory: getApplicationSupportDirectory,
          executableDirectory: () => File(Platform.resolvedExecutable).parent,
        );
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

          // 降级可见性兜底：原生窗口的 show 由首帧后的 reveal 路径负责，
          // 但 init 失败时 reveal 可能同样受阻，降级文字态将对用户不可见
          // （UAT Test 16 首轮实测发现的"隐形孤儿进程"）。这里 best-effort
          // 直接 show——窗口以系统默认标题栏形态出现（紧急态可接受），
          // setPreventClose 未生效故默认关闭行为可用。若 show 本身失败，
          // 仅记录、不再上抛，保证容纳路径本身不会制造新的未处理异常。
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

        // 启动期一次性 DWM 能力探测（D-01，Phase 6 ENAB-01）：同步 FFI，
        // 结果写入门面自有 notifier（WindowServiceState.dwmCapabilities
        // 转发同一实例）。失败优雅降级——快照保持 null，Phase 7/8 属性门
        // 视 null 为「能力未知」跳过属性调用；本 try/catch 保证探测故障
        // 不阻断应用启动。
        try {
          DwmCapabilities.I.probe();
        } on Exception catch (error, stackTrace) {
          KernelLogger.I.e(
            '[main] DwmCapabilities probe failed: $error',
            error: error,
            stackTrace: stackTrace,
          );
        }

        runApp(
          App(
            startupTimeline: startupTimeline,
            windowService: windowService,
            windowInitError: windowInitError,
          ),
        );

        // v0.0.4 空白窗口修复：首帧栅格化后再亮窗。此前窗口在
        // windowService.init()（runApp 之前）内 show，首帧尚未渲染，
        // 用户看到数百毫秒空白窗口。窗口隐藏态完成几何恢复 + runApp
        // 排程首帧 → 此处亮窗，窗口出现即带完整内容。
        unawaited(_revealWindowAfterFirstFrame(windowService));
      }, BootstrapErrorFallback.report) ??
      Future<void>.value();
}

/// 首帧栅格化后亮窗 — 窗口出现即带完整首帧内容（v0.0.4 空白窗口修复）。
///
/// 等待 [WidgetsBinding.waitUntilFirstFrameRasterized]，带超时兜底：
/// 若引擎在隐藏窗口下迟迟不产帧（平台差异风险），超时后照常亮窗 ——
/// 最坏情形退化为旧行为（短暂空白），窗口绝不因等待而永不显示。
/// 等待或亮窗失败都 best-effort 直接 show（与 init 失败降级同一兜底），
/// 绝不影响已 runApp 的应用本体。
Future<void> _revealWindowAfterFirstFrame(WindowService windowService) async {
  try {
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized.timeout(
      _firstFrameRevealTimeout,
    );
  } on Object catch (error, stackTrace) {
    // 超时/等待异常不阻断亮窗 — 记 warn 后继续。
    KernelLogger.I.w(
      '[main] First-frame wait timed out or failed: $error',
      context: <String, Object?>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );
  }
  try {
    await windowService.reveal();
  } on Object catch (error, stackTrace) {
    KernelLogger.I.e(
      '[main] Window reveal failed: $error',
      error: error,
      stackTrace: stackTrace,
    );
    // 与 init 失败降级同款 best-effort 直接 show；再失败仅记录，不上抛。
    try {
      await windowManager.show();
    } on Object catch (showError, showStack) {
      KernelLogger.I.w(
        '[main] Degraded window show failed: $showError',
        context: <String, Object?>{
          'error': '$showError',
          'stackTrace': '$showStack',
        },
      );
    }
  }
}

/// 首帧等待超时 — 覆盖引擎在隐藏窗口下不产帧的平台差异风险。
const _firstFrameRevealTimeout = Duration(milliseconds: 800);

/// Resolves and activates durable diagnostic evidence after global capture is live.
///
/// This asynchronous side effect intentionally does not delay MediaKit, window,
/// or runApp. Its failure is reported only through KernelLogger to avoid reporter
/// reentrancy while the file effect is itself unavailable.
Future<void> _activateDiagnosticLog(
  DelegatingDiagnosticLogEffect _, // 参数保留兼容调用契约 — 落点解析已收敛到 resolve 链.
) async {
  try {
    // 设置加载先于位置解析且同在 unawaited 激活路径内（RESEARCH Pitfall 7）：
    // 绝不阻塞 MediaKit/window/runApp。store 构造同步零 I/O；save 失败静默
    // 回退（D-01）。AS provider 供 WR-06 两层回退：exe 旁目录不可写
    //（MSIX/ACL 保护目录）时设置改存 Application Support，探测一次性在
    // load 内完成并记住层级。
    await ErrorFeedbackSettings.I.load(
      applicationSupportDirectory: getApplicationSupportDirectory,
    );
    // 双层链（D-07：G-04-1 后无用户配置目录）：exe 根 logs/error.log 优先，
    // exe 层不可写时静默回退 Application Support logs/。
    final result = await ErrorLogLocation.resolve(
      applicationSupportDirectory: getApplicationSupportDirectory,
      // 组合根注入运行中可执行文件所在目录（kernel 不直接读进程位置；
      // 生产注入真实 exe 目录，测试注入临时目录）。
      executableDirectory: () => File(Platform.resolvedExecutable).parent,
    );
    switch (result) {
      case ErrorLogLocationResolved(:final file):
        // 启动激活收敛到协调器的唯一激活实现（research 单一激活实现
        // caveat）：sink 构造与 delegate.activate 只存在于协调器内。
        DiagnosticLogTarget.I.activateResolved(file: file);
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
