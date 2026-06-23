import 'package:flutter/material.dart';

import 'app.dart';
import 'infra/event_bus/event_bus.dart';
import 'infra/logger/app_logger.dart';
import 'infra/mpv/mpv_bindings.dart';
import 'infra/mpv/mpv_adapter.dart';
import 'infra/mpv/mpv_render_service.dart';
import 'infra/window/window_service.dart';
import 'feature/player/player_feature.dart';
import 'feature/window/window_feature.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLogger.initLog();

  final bus = EventBus();

  // Infra
  final bindings = MpvBindings();
  final mpv = MpvAdapter(bindings, bus);
  final renderService = MpvRenderService(bus, mpv);
  final windowService = WindowService(bus);

  // Features
  final playerFeature = PlayerFeature(mpv, bus);
  final windowFeature = WindowFeature(windowService, bus);

  // Init
  await windowService.init();
  playerFeature.init();
  windowFeature.init();
  renderService.init();

  // Initialize mpv engine
  await mpv.init();

  runApp(App(bus: bus, mpv: mpv, renderService: renderService));
}
