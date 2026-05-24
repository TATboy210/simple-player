import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kernel/persistence/settings_store.dart';
import '../kernel/utils/perf_monitor.dart';
import '../src/rust/frb_generated.dart';
import '../window/window_service.dart';

/// 应用初始化序列 — 单一职责：启动时的一次性配置
class AppBootstrap {
  AppBootstrap._();

  /// 运行所有初始化步骤，返回 SharedPreferences 实例
  static Future<SharedPreferences> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化 Rust/FRB 桥接（仅在 libmpv 可用时）
    if (_canInitRust()) {
      try {
        await RustLib.init();
        debugPrint('[bootstrap] Rust bridge initialized');
      } catch (e) {
        debugPrint('[bootstrap] Rust bridge init failed: $e');
      }
    } else {
      debugPrint('[bootstrap] Rust bridge skipped (libmpv not available)');
    }

    // 启用性能监控（profile 模式下自动启用）
    PerfMonitor.instance.enable();

    final prefs = await SharedPreferences.getInstance();
    SettingsStore.prewarm(prefs);

    await WindowService.instance.initialize();

    return prefs;
  }

  static bool _canInitRust() {
    try {
      final exeDir = Platform.resolvedExecutable;
      final dir = exeDir.substring(0, exeDir.lastIndexOf('\\'));
      return File('$dir\\rust_lib_simple_player_flutter.dll').existsSync();
    } catch (_) {
      return false;
    }
  }
}
