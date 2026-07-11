import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/bridge/desktop_fullscreen_adapter.dart';
import 'kernel/bridge/desktop_fullscreen_driver_factory.dart';
import 'kernel/bridge/window_service.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'kernel/utils/log.dart';
import 'kernel/utils/memory_monitor.dart';

/// 编译期开关：--dart-define=USE_NEW_FULLSCREEN=true 启用新全屏适配器 (D-27)。
///
/// 默认 true（RC 版本）。设为 false 回退到旧 fullscreen_window 实现。
/// 新实现通过 FullscreenAdapter 统一管理命令队列、状态回读和恢复策略。
const bool _useNewFullscreen = bool.fromEnvironment(
  'USE_NEW_FULLSCREEN',
  defaultValue: true,
);

// 编译期开关: --dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true 启用 Windows FFI 驱动 (D-P03)。
// 仅在 USE_NEW_FULLSCREEN=true 时生效。
// 默认 false，Windows 使用 window_manager 包装。
// macOS/Linux 始终使用各自的平台驱动，此 flag 仅影响 Windows。
// 此 flag 由 DesktopFullscreenDriverFactory 内部读取 (bool.fromEnvironment)。

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLog();
  MemoryMonitor.start();

  // SettingsStore 预热 — 在 WindowService.init() 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // P0-4 初始化顺序 (Phase C 更新):
  //   1. DesktopFullscreenDriverFactory.create() ← 每平台最优驱动 (D-P02)
  //   2. DesktopFullscreenAdapter(driver)         ← 持有 driver + 回调转发 (D-P11)
  //   3. WindowService(fullscreenAdapter)         ← 转发全屏操作
  DesktopFullscreenAdapter? fullscreenAdapter;
  if (_useNewFullscreen) {
    final driver = DesktopFullscreenDriverFactory.create();
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

  runApp(App(
    coordinator: coordinator,
    windowService: windowService,
  ));
}
