import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/utils/perf_monitor.dart';
import 'src/rust/frb_generated.dart';
import 'window/window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Rust/FRB 桥接（仅在 libmpv 可用时）
  if (_canInitRust()) {
    try {
      await RustLib.init();
      debugPrint('[main] Rust bridge initialized');
    } catch (e) {
      debugPrint('[main] Rust bridge init failed: $e');
    }
  } else {
    debugPrint('[main] Rust bridge skipped (libmpv not available)');
  }

  // 启用性能监控（profile 模式下自动启用）
  PerfMonitor.instance.enable();

  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  await WindowService.instance.initialize();

  runApp(App(sharedPreferences: prefs));
}

bool _canInitRust() {
  // 检查 rust DLL 是否存在且能加载（依赖 libmpv-2.dll）
  try {
    final exeDir = Platform.resolvedExecutable;
    final dir = exeDir.substring(0, exeDir.lastIndexOf('\\'));
    return File('$dir\\rust_lib_simple_player_flutter.dll').existsSync();
  } catch (_) {
    return false;
  }
}
