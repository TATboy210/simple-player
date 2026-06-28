import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/bridge/window_service.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/engine/mock_engine.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'kernel/utils/log.dart';
import 'kernel/utils/memory_monitor.dart';

/// 编译期开关：--dart-define=USE_MOCK_ENGINE=true 启用模拟引擎。
const bool _useMockEngine = bool.fromEnvironment(
  'USE_MOCK_ENGINE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLog();
  MemoryMonitor.start();

  // SettingsStore 预热 — 在 WindowService.init() 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // 窗口初始化 — WindowService.init() 内部处理全部 bootstrap
  final windowService = WindowService();
  await windowService.init();

  final coordinator = StartupCoordinator();
  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');

  // fire-and-forget: 预热 MDK 引擎（FFmpeg codec 注册 + D3D11 上下文）
  unawaited(
    EnginePrewarm.prewarm(
      onProgress: (p, msg) =>
          coordinator.report(StartupPhase.infrastructure, 0.4 + p * 0.2, msg),
    ),
  );

  coordinator.report(StartupPhase.infrastructure, 1.0, 'Infrastructure ready');

  final engineOverride = _useMockEngine ? MockEngine() : null;
  runApp(App(
    coordinator: coordinator,
    windowService: windowService,
    engineOverride: engineOverride,
  ));
}
