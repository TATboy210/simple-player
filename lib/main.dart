import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/bridge/window_service.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'kernel/utils/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 自定义 mdk.Player 的 updateTexture() 同样经由 fvp 平台通道创建 Flutter Texture。
  // 必须早于 EnginePrewarm 和播放器服务构造，避免首个播放器拿到未注册的平台实现。
  fvp.registerWith();

  await initLog();

  // SettingsStore 预热 — 在 WindowService.init() 回调前缓存 prefs
  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  // WindowService 内部通过 _createDriver() 自动创建平台全屏驱动
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

  runApp(App(
    coordinator: coordinator,
    windowService: windowService,
  ));
}
