import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' as wm;

import '../kernel/models/aspect_ratio_mode.dart';

/// Re-export DragToResizeArea for UI 层 — 避免消费者直接 import window_manager 包
export 'package:window_manager/window_manager.dart' show DragToResizeArea;

// ═══════════════════════════════════════════════════════════════════════
// WindowConstants — 固定值
// ═══════════════════════════════════════════════════════════════════════

class WindowConstants {
  WindowConstants._();

  static const defaultWidth = 1280.0;
  static const defaultHeight = 720.0;
  static const minSize = Size(800, 450);
  static const autoHideCursor = true;
}

// ═══════════════════════════════════════════════════════════════════════
// WindowState — 4 个 ValueNotifier 容器
// ═══════════════════════════════════════════════════════════════════════

class WindowState {
  final ValueNotifier<bool> fullscreen = ValueNotifier(false);
  final ValueNotifier<bool> maximized = ValueNotifier(false);
  final ValueNotifier<bool> alwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> focused = ValueNotifier(true);

  void dispose() {
    fullscreen.dispose();
    maximized.dispose();
    alwaysOnTop.dispose();
    focused.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WindowLifecycleBus — 瞬态事件总线 + isOperating
// ═══════════════════════════════════════════════════════════════════════

/// 窗口瞬态事件类型
enum WindowEventType { resizeStart, resizeEnd, moveStart, moveEnd }

/// 窗口事件（类型 + 时间戳 + 可选尺寸）
class WindowEvent {
  final WindowEventType type;
  final DateTime timestamp;
  final Size? size;
  WindowEvent(this.type, {this.size}) : timestamp = DateTime.now();

  bool get isStart =>
      type == WindowEventType.resizeStart ||
      type == WindowEventType.moveStart;
  bool get isEnd =>
      type == WindowEventType.resizeEnd || type == WindowEventType.moveEnd;
  bool get isResize =>
      type == WindowEventType.resizeStart ||
      type == WindowEventType.resizeEnd;
  bool get isMove =>
      type == WindowEventType.moveStart || type == WindowEventType.moveEnd;
}

/// 统一窗口生命周期事件总线（singleton）
///
/// 广播 resize/move 等瞬态事件。消费方可按类型过滤。
/// 同时暴露 [isOperating] notifier —— 任何"窗口正在被用户操作"的状态
/// （resize 或 move）为 true，用于统一暂停 BackdropFilter / 动画。
class WindowLifecycleBus {
  WindowLifecycleBus._();
  static final WindowLifecycleBus instance = WindowLifecycleBus._();

  final _controller = StreamController<WindowEvent>.broadcast();

  /// 所有窗口事件流（按需过滤）
  Stream<WindowEvent> get events => _controller.stream;

  /// "窗口正在被用户操作" —— resize 或 move 期间为 true
  final ValueNotifier<bool> isOperating = ValueNotifier(false);

  int _resizeCount = 0;
  int _moveCount = 0;

  void dispatch(WindowEvent event) {
    _controller.add(event);
    isOperating.value = event.isStart;

    final label = event.isResize ? 'window_resize' : 'window_move';
    if (event.isStart) {
      if (event.isResize) _resizeCount++;
      if (event.isMove) _moveCount++;
      developer.Timeline.startSync(label);
    } else {
      developer.Timeline.finishSync();
    }
  }

  /// 窗口操作统计（供 PerfMonitor.exportStats 使用）
  Map<String, dynamic> get stats => {
        'resizeCount': _resizeCount,
        'moveCount': _moveCount,
      };

  void dispose() {
    _controller.close();
    isOperating.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AspectRatioService — 宽高比约束 + 失败回滚
// ═══════════════════════════════════════════════════════════════════════

/// 宽高比约束服务 — 通过 windowManager.setAspectRatio() 控制
///
/// 无视频时锁定 16:9，播放视频时匹配视频比例。
/// 设置为 0 取消约束。
class AspectRatioService {
  AspectRatioService._({Future<void> Function(double)? applyAspectRatio})
      : _applyAspectRatio = applyAspectRatio ?? _defaultApply;

  /// 测试用工厂：注入自定义 apply 函数替代 windowManager
  factory AspectRatioService.test(Future<void> Function(double) apply) {
    return AspectRatioService._(applyAspectRatio: apply);
  }

  static AspectRatioService? _instance;

  static AspectRatioService get I =>
      _instance ??= AspectRatioService._();

  /// 重置单例（仅测试用）
  @visibleForTesting
  static void resetForTest() {
    _instance?.dispose();
    _instance = null;
  }

  /// 替换单例为测试实例（仅测试用）
  @visibleForTesting
  static AspectRatioService setForTest(Future<void> Function(double) apply) {
    _instance?.dispose();
    final testInstance = AspectRatioService.test(apply);
    _instance = testInstance;
    return testInstance;
  }

  static Future<void> _defaultApply(double ratio) =>
      wm.windowManager.setAspectRatio(ratio);

  final Future<void> Function(double) _applyAspectRatio;

  /// 16:9（默认空闲比例）
  static final ratio16x9 = AspectRatioMode.ratio16_9.mdkValue;

  /// 4:3
  static final ratio4x3 = AspectRatioMode.ratio4_3.mdkValue;

  double _current = 0.0;

  double get current => _current;

  /// UI rebuild notifier — fires on every ratio change
  final ValueNotifier<double> ratioNotifier = ValueNotifier<double>(0.0);

  /// 设置宽高比约束（0 = 无约束）
  Future<void> setAspectRatio(double ratio) async {
    if (_current == ratio) return;
    final previous = _current; // RC-6: 保存用于失败回滚
    _current = ratio;
    ratioNotifier.value = ratio;
    try {
      await _applyAspectRatio(ratio);
    } on Exception catch (e) {
      _current = previous; // RC-6: 回滚到之前的状态
      ratioNotifier.value = previous;
      debugPrint('[AspectRatio] setAspectRatio($ratio) failed: $e');
    }
  }

  /// 锁定 16:9（无视频空闲状态）
  Future<void> lock16x9() => setAspectRatio(ratio16x9);

  /// 锁定 4:3
  Future<void> lock4x3() => setAspectRatio(ratio4x3);

  /// 匹配视频宽高比（width/height 比值）
  Future<void> matchVideo(double ratio) {
    if (ratio <= 0) return Future.value();
    return setAspectRatio(ratio);
  }

  /// 取消约束
  Future<void> unlock() => setAspectRatio(0.0);

  /// 当前比例的显示标签
  String get currentLabel {
    if (_current == 0.0) return '自由';
    for (final mode in AspectRatioMode.values) {
      if ((_current - mode.mdkValue).abs() < 0.01) return mode.label;
    }
    return '${_current.toStringAsFixed(2)}:1';
  }

  void dispose() {
    ratioNotifier.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WindowService — 初始化 + 8 个动作 + OS 回调驱动 state
// ═══════════════════════════════════════════════════════════════════════

class WindowService {
  WindowService._();
  static WindowService instance = WindowService._();

  final WindowState state = WindowState();

  /// 仅用于测试 — 替换 singleton 实例
  @visibleForTesting
  static void overrideInstance(WindowService svc) => instance = svc;

  final _resizeController = StreamController<bool>.broadcast();
  Stream<bool> get onResize => _resizeController.stream;

  final _moveController = StreamController<bool>.broadcast();
  Stream<bool> get onMove => _moveController.stream;

  Future<void> initialize() async {
    await wm.windowManager.ensureInitialized();

    final windowOptions = wm.WindowOptions(
      size: const Size(
        WindowConstants.defaultWidth,
        WindowConstants.defaultHeight,
      ),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: wm.TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
      await wm.windowManager.setMinimumSize(WindowConstants.minSize);
      await wm.windowManager.setPreventClose(true);
      await wm.windowManager.setAsFrameless();
      // 阴影策略：macOS 禁用原生阴影（VirtualWindowFrame 自带），Windows 保留
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await wm.windowManager.setHasShadow(false);
      }
      await wm.windowManager.show();
      await wm.windowManager.focus();
      wm.windowManager.addListener(_WindowListener(this));
    });
  }

  Future<void> setFullscreen(bool value) async {
    await wm.windowManager.setFullScreen(value);
  }

  Future<void> maximize() async {
    await wm.windowManager.maximize();
  }

  Future<void> restore() async {
    await wm.windowManager.unmaximize();
  }

  Future<void> toggleMaximize() async {
    if (state.maximized.value) {
      await restore();
    } else {
      await maximize();
    }
  }

  Future<void> minimize() async {
    await wm.windowManager.minimize();
  }

  Future<void> startDragging() async {
    await wm.windowManager.startDragging();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await wm.windowManager.setAlwaysOnTop(value);
    state.alwaysOnTop.value = value; // 无 OS listener，必须手动同步
  }

  Future<void> close() async {
    await wm.windowManager.setPreventClose(false);
    await wm.windowManager.close();
  }

  void dispose() {
    _resizeController.close();
    _moveController.close();
    WindowLifecycleBus.instance.dispose();
    AspectRatioService.I.dispose();
    state.dispose();
  }
}

class _WindowListener extends wm.WindowListener {
  _WindowListener(this._svc);
  final WindowService _svc;

  @override
  void onWindowMaximize() => _svc.state.maximized.value = true;

  @override
  void onWindowUnmaximize() => _svc.state.maximized.value = false;

  @override
  void onWindowEnterFullScreen() =>
      _svc.state.fullscreen.value = true;

  @override
  void onWindowLeaveFullScreen() =>
      _svc.state.fullscreen.value = false;

  @override
  void onWindowFocus() => _svc.state.focused.value = true;

  @override
  void onWindowBlur() => _svc.state.focused.value = false;

  @override
  void onWindowClose() => _svc.close();

  @override
  void onWindowResize() {
    _svc._resizeController.add(true);
    _dispatchWithSize(WindowEventType.resizeStart);
  }

  @override
  void onWindowResized() {
    _svc._resizeController.add(false);
    _dispatchWithSize(WindowEventType.resizeEnd);
  }

  @override
  void onWindowMove() {
    _svc._moveController.add(true);
    WindowLifecycleBus.instance.dispatch(
      WindowEvent(WindowEventType.moveStart),
    );
  }

  @override
  void onWindowMoved() {
    _svc._moveController.add(false);
    WindowLifecycleBus.instance.dispatch(
      WindowEvent(WindowEventType.moveEnd),
    );
  }

  Future<void> _dispatchWithSize(WindowEventType type) async {
    final size = await wm.windowManager.getSize();
    WindowLifecycleBus.instance.dispatch(WindowEvent(type, size: size));
  }
}

