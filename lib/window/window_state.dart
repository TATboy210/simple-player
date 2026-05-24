import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'window_constants.dart';
import 'window_service.dart';

export 'window_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// WindowState — 响应式状态层, UI 直接访问
// ═══════════════════════════════════════════════════════════════════════

class WindowState {
  // ── Singleton ──

  static WindowState? _instance;
  static WindowState get I => _instance!;
  static void inject(WindowState impl) => _instance = impl;

  // ── 响应式状态 ──

  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  final isMaximized = ValueNotifier<bool>(false);
  final interaction = ValueNotifier<WindowInteractionState>(
    WindowInteractionState.idle,
  );
  bool get isResizing =>
      interaction.value == WindowInteractionState.resizing;

  // ── 命令委托 ──

  late final _svc = WindowService(this);

  Future<void> minimize() => _svc.minimize();
  Future<void> toggleMaximize() => _svc.toggleMaximize();
  Future<void> close() => _svc.close();
  Future<void> startDragging() => _svc.startDragging();
  Future<void> toggleAlwaysOnTop() => _svc.toggleAlwaysOnTop();
  Future<void> toggleFullscreen() => _svc.toggleFullscreen();
  Future<void> exitFullscreen() => _svc.exitFullscreen();

  Future<void> init(SharedPreferences prefs) => _svc.init(prefs);
  Future<void> dispose() => _svc.dispose();
}
