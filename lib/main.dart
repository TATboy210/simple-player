import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'kernel/window_bridge/window_manager_service.dart';

/// 应用组合根：初始化平台基础设施并将已准备的窗口服务注入 App。
Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  MediaKit.ensureInitialized();
  KernelLoggerImpl.init();
  await windowManager.ensureInitialized();

  final coordinator = StartupCoordinator();
  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');
  final windowService = WindowService();
  String? windowInitError;
  try {
    await windowService.init();
    coordinator.report(
      StartupPhase.infrastructure,
      1.0,
      'Infrastructure ready',
    );
  } on Object catch (error, stackTrace) {
    windowInitError = '$error';
    coordinator.report(
      StartupPhase.infrastructure,
      1.0,
      'Window initialization failed',
    );
    KernelLogger.I.e(
      '[main] Window initialization failed: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  runApp(
    App(
      coordinator: coordinator,
      windowService: windowService,
      windowInitError: windowInitError,
    ),
  );
}
