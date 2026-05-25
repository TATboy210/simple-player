import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'kernel/engine/engine_prewarm.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'src/rust/frb_generated.dart';
import 'window/window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final coordinator = StartupCoordinator();

  final rustAvailable = _canInitRust();
  if (!rustAvailable) {
    debugPrint('[main] Rust bridge skipped (libmpv not available)');
  }

  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');

  // 并行启动三个独立的 async 操作
  final rustFuture = rustAvailable
      ? RustLib.init()
            .then((_) {
              debugPrint('[main] Rust bridge initialized');
              coordinator.report(
                StartupPhase.infrastructure,
                0.6,
                'Rust ready',
              );
            })
            .catchError((e) {
              debugPrint('[main] Rust bridge init failed: $e');
            })
      : Future.value();
  final prefsFuture = SharedPreferences.getInstance();
  final windowFuture = WindowService.instance.initialize();

  // fire-and-forget: 预热 MDK 引擎（FFmpeg codec 注册 + D3D11 上下文）
  unawaited(
    EnginePrewarm.prewarm(
      onProgress: (p, msg) =>
          coordinator.report(StartupPhase.infrastructure, 0.4 + p * 0.2, msg),
    ),
  );

  // SharedPreferences 完成后立即 prewarm（WindowService 可能间接依赖）
  final prefs = await prefsFuture;
  SettingsStore.prewarm(prefs);
  coordinator.report(StartupPhase.infrastructure, 0.8, 'Settings loaded');

  // 等待剩余两个并行任务完成
  await Future.wait([rustFuture, windowFuture]);
  coordinator.report(StartupPhase.infrastructure, 1.0, 'Infrastructure ready');

  runApp(App(coordinator: coordinator));
}

bool _canInitRust() {
  try {
    final exeDir = Platform.resolvedExecutable;
    final dir = exeDir.substring(0, exeDir.lastIndexOf('\\'));
    return File('$dir\\rust_lib_simple_player_flutter.dll').existsSync();
  } on FileSystemException {
    return false;
  }
}
