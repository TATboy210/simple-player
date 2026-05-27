import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'window/window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final coordinator = StartupCoordinator();
  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');

  // 并行启动两个独立的 async 操作
  final prefsFuture = SharedPreferences.getInstance();
  final windowFuture = WindowService.instance.initialize();

  // fire-and-forget: 预热 MDK 引擎（FFmpeg codec 注册 + D3D11 上下文）
  unawaited(
    EnginePrewarm.prewarm(
      onProgress: (p, msg) =>
          coordinator.report(StartupPhase.infrastructure, 0.4 + p * 0.2, msg),
    ),
  );

  // SharedPreferences 完成后立即 prewarm
  final prefs = await prefsFuture;
  SettingsStore.prewarm(prefs);
  coordinator.report(StartupPhase.infrastructure, 0.8, 'Settings loaded');

  // 等待窗口初始化完成
  await windowFuture;
  coordinator.report(StartupPhase.infrastructure, 1.0, 'Infrastructure ready');

  runApp(App(coordinator: coordinator));
}
