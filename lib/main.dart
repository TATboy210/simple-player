import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';

/// 应用组合根：初始化平台基础设施并将已准备的窗口服务注入 App。
///
/// 初始化顺序均为硬性依赖：绑定 → 引擎 → 日志 → 窗口管理器 → 窗口服务；
/// 任何一步失败不阻断 runApp（错误态由 UI 层呈现），保证诊断信息可达。
Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  MediaKit.ensureInitialized();
  KernelLoggerImpl.init();
  await windowManager.ensureInitialized();

  // 启动时序诊断 — 打点式纯计时器，无 UI 广播职责（见 StartupTimeline 注释）。
  final startupTimeline = StartupTimeline();
  final windowService = WindowService();
  String? windowInitError;
  try {
    await windowService.init();
    startupTimeline.mark(StartupTimeline.phaseInfrastructure);
  } on Object catch (error, stackTrace) {
    windowInitError = '$error';
    KernelLogger.I.e(
      '[main] Window initialization failed: $error',
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
}
