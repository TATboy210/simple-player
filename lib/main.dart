import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/bridge/window_bootstrap.dart';
import 'kernel/bridge/window_service.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'kernel/utils/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLog();

  // SettingsStore 预热 — 在 waitUntilReadyToShow 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // window_manager 初始化 — 一步到位配置窗口，避免启动闪烁
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    minimumSize: Size(854, 480),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await WindowService.removeBorderImmediate();

    // 恢复保存的窗口几何（D-02: 清除全屏标志避免崩溃锁死）
    final settings = await SettingsStore.load();
    await WindowBootstrap.clearFullscreenIfSaved(settings);
    await WindowBootstrap.restoreOrCenter(settings);

    await windowManager.show();
    await windowManager.focus();

    // 恢复最大化状态（show 后调用，窗口管理器已就绪）
    if (settings.isMaximized) {
      await windowManager.maximize();
    }
  });

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

  runApp(App(coordinator: coordinator));
}
