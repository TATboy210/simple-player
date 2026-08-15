import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'kernel/window_manager_service/window_manager_service.dart';
import 'kernel/startup/startup_coordinator.dart';

Future<void> main() async {
  // Debug builds expose Flutter's VM service extensions for Marionette MCP;
  // release builds keep the standard binding and do not expose test controls.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // media_kit (libmpv) 是唯一后端 — 加载 native libmpv.
  // 必须早于 MediaKitEngine 构造 (PlayerServices.init 内). fvp/MDK 已移除.
  MediaKit.ensureInitialized();

  final windowService = WindowService();
  await windowService.init();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  final coordinator = StartupCoordinator();
  coordinator.report(StartupPhase.infrastructure, 0.1, 'Initializing...');
  coordinator.report(StartupPhase.infrastructure, 1.0, 'Infrastructure ready');

  runApp(
    App(
      coordinator: coordinator,
      windowService: windowService,
      savedThemeMode: savedThemeMode,
    ),
  );
}
