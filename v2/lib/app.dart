import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/events/player_events.dart';
import 'infra/event_bus/event_bus.dart';
import 'infra/mpv/mpv_adapter.dart';
import 'infra/mpv/mpv_render_service.dart';
import 'ui/player_screen.dart';

/// 应用壳 — MaterialApp + PlayerScreen + 退出清理
class App extends StatefulWidget {
  final EventBus bus;
  final MpvAdapter mpv;
  final MpvRenderService renderService;

  const App({
    super.key,
    required this.bus,
    required this.mpv,
    required this.renderService,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-load test file from Downloads
    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      const testPath = r'C:\Users\35490\Downloads\6328481-uhd_4096_2160_25fps.mp4';
      debugPrint('[App] Firing OpenCommand: $testPath');
      widget.bus.fire(OpenCommand(testPath));
    });
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    try {
      // 渲染资源必须在 mpv handle 之前释放
      await widget.renderService.dispose();
      widget.mpv.dispose();
      widget.bus.dispose();
    } catch (e) {
      debugPrint('[App] cleanup failed: $e');
    }
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Player v2',
      theme: ThemeData.dark(useMaterial3: true),
      home: PlayerScreen(
        bus: widget.bus,
        mpv: widget.mpv,
        renderService: widget.renderService,
      ),
    );
  }
}
