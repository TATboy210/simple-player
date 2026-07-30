import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/bridge/window_service.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit (libmpv) 是唯一后端 — 加载 native libmpv.
  // 必须早于 MediaKitEngine 构造 (PlayerServices.init 内). fvp/MDK 已移除.
  MediaKit.ensureInitialized();

  // SettingsStore 预热 — 在 WindowService.init() 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // WindowService 内部通过 _createDriver() 自动创建平台全屏驱动
  final windowService = WindowService();
  await windowService.init();

  final coordinator = StartupCoordinator();
  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');
  coordinator.report(StartupPhase.infrastructure, 1.0, 'Infrastructure ready');

  runApp(App(coordinator: coordinator, windowService: windowService));
}
