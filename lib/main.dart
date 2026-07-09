import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/bridge/desktop_fullscreen_adapter.dart';
import 'kernel/bridge/desktop_fullscreen_driver.dart';
import 'kernel/bridge/fullscreen_adapter.dart';
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

/// 编译期开关：--dart-define=USE_NEW_FULLSCREEN=true 启用新全屏适配器 (D-27)。
///
/// 默认 false，使用旧 fullscreen_window 实现。
/// 新实现通过 FullscreenAdapter 统一管理命令队列、状态回读和恢复策略。
const bool _useNewFullscreen = bool.fromEnvironment(
  'USE_NEW_FULLSCREEN',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLog();
  MemoryMonitor.start();

  // SettingsStore 预热 — 在 WindowService.init() 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // P0-4 初始化顺序 (冻结，无循环依赖):
  //   1. DesktopFullscreenDriver()        ← 纯 windowManager API
  //   2. DesktopFullscreenAdapter(driver)  ← 持有 driver
  //   3. WindowService(fullscreenAdapter)  ← 转发全屏操作
  FullscreenAdapter? fullscreenAdapter;
  if (_useNewFullscreen) {
    final driver = DesktopFullscreenDriver();
    fullscreenAdapter = DesktopFullscreenAdapter(driver);
  }

  // 窗口初始化 — WindowService.init() 内部处理全部 bootstrap
  final windowService = WindowService(
    fullscreenAdapter: fullscreenAdapter,
  );
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
