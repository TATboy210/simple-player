import 'package:flutter/foundation.dart';

/// 窗口模式枚举
enum WindowMode { windowed, fullscreen }

/// 窗口操作抽象 — kernel 通过此接口控制窗口，不依赖 window/ 实现
///
/// 注入方式: main.dart 中调用 WindowBridge.inject(impl)
/// 未注入时返回 NoopWindowBridge（安全降级，不崩溃）
abstract class WindowBridge {
  static WindowBridge get I => _instance ?? _noop;

  static WindowBridge? _instance;
  static final _noop = NoopWindowBridge();

  /// 注入窗口实现（由 WindowBootstrap 调用）
  static void inject(WindowBridge impl) => _instance = impl;

  // ── Commands ──

  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<void> startDragging();
  Future<void> toggleFullscreen();
  Future<void> exitFullscreen();
  Future<void> toggleAlwaysOnTop();

  // ── Reactive State ──

  ValueNotifier<WindowMode> get mode;
  ValueNotifier<bool> get isAlwaysOnTop;
  ValueNotifier<bool> get isMaximized;
  ValueNotifier<bool> get isResizing;

  // ── Lifecycle ──

  Future<void> init();
  Future<void> dispose();
}

/// 未注入时的安全降级 — 所有操作为空操作
class NoopWindowBridge implements WindowBridge {
  @override
  final mode = ValueNotifier(WindowMode.windowed);
  @override
  final isAlwaysOnTop = ValueNotifier(false);
  @override
  final isMaximized = ValueNotifier(false);
  @override
  final isResizing = ValueNotifier(false);

  @override
  Future<void> minimize() async {}
  @override
  Future<void> toggleMaximize() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> startDragging() async {}
  @override
  Future<void> toggleFullscreen() async {}
  @override
  Future<void> exitFullscreen() async {}
  @override
  Future<void> toggleAlwaysOnTop() async {}
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
}
