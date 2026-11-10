import 'package:flutter/foundation.dart';

import '../port/native_window.dart';
import '../window_bridge.dart';

/// 窗口模式控制（契约 4）— 意图先落 + 几何边沿现查校准。
///
/// setMode 语义 =「意图立即提交，原生状态在下一几何边沿校准」：
/// nativeapi 命令为同步 FFI marshal，无事件流可等（契约 1 零订阅），
/// maximize/unmaximize 的实际落定由引擎指标边沿触发 [syncFromNative]
/// 现查 `isMaximized` 收敛 — 与阶段二实机验证的行为一致。
class ModeController {
  ModeController({required this.mode, required this.window});

  /// 模式单一数据源（UI 经 WindowBridge.mode 消费）。
  final ValueNotifier<WindowMode> mode;

  /// 取当前绑定的原生窗口（未绑定为 null）。
  final NativeWindow? Function() window;

  bool _fullscreenIntent = false;

  /// 全屏意图已提交（进入/退出过渡期间校准让位，防止原生中间态把
  /// fullscreen 冲成 windowed）。
  bool get fullscreenIntent => _fullscreenIntent;

  /// 提交目标模式。全屏=同步属性写；maximize/unmaximize=命令即返。
  Future<void> setMode(WindowMode target) async {
    final window = this.window();
    if (window == null) return;
    final wasFullscreen = mode.value.isFullscreen;
    if (target.isFullscreen) {
      if (wasFullscreen) return;
      // 先提交意图+模式（全屏期间原生 maximize 映射回 fullscreen），再执行
      // 原生全屏。全屏属性经窗口线程同步执行，返回即落定。
      _fullscreenIntent = true;
      mode.value = WindowMode.fullscreen;
      window.isFullScreen = true;
      return;
    }
    _fullscreenIntent = false;
    if (mode.value == target) return;
    mode.value = target;
    if (wasFullscreen) {
      // 退出全屏原生已还原进入前几何（含最大化）；目标 windowed 但宿主实际
      // 是最大化时落回 maximized。
      window.isFullScreen = false;
      if (target.isWindowed && window.isMaximized) {
        mode.value = WindowMode.maximized;
      }
      return;
    }
    if (target.isMaximized) {
      window.maximize();
    } else {
      window.unmaximize();
    }
  }

  /// 现查宿主 `isMaximized` 校准 [mode]（一次轻量 FFI）。
  ///
  /// 全屏意图/全屏中跳过 — 全屏的原生形态不是最大化，查到 windowed 也会
  /// 把 fullscreen 冲掉。[revealed]=false（亮窗前）不校准。
  void syncFromNative({required bool revealed}) {
    final window = this.window();
    if (window == null || !revealed) return;
    if (_fullscreenIntent || mode.value.isFullscreen) return;
    mode.value = window.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }
}
