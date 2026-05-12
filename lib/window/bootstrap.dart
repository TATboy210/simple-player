import 'package:shared_preferences/shared_preferences.dart';

import '../kernel/bridge/window_bridge.dart';
import 'window_service.dart';

/// 窗口系统引导 — 在 main.dart 中调用
///
/// 职责:
/// 1. 创建 WindowService 实例
/// 2. 注入到 WindowBridge（kernel 通过此接口访问窗口）
/// 3. 初始化 window_manager（frameless、恢复几何、显示窗口）
class WindowBootstrap {
  WindowBootstrap._();

  /// 初始化窗口系统
  ///
  /// 必须在 runApp() 之前调用，在 SharedPreferences.getInstance() 之后。
  static Future<void> init(SharedPreferences prefs) async {
    final service = WindowService(prefs);
    WindowBridge.inject(service);
    await service.init();
  }
}
