import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'desktop_fullscreen_adapter.dart';
import 'display_enumerator.dart';
import 'win32/win32_display_enumerator.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';

/// 窗口管理服务 — 薄协调者，组合职责组件。
///
/// 职责:
/// - WindowState: 状态容器 (mode, windowSize, isResizing, isAlwaysOnTop)
/// - WindowPersistence: debounce 持久化
///
/// OS 回调驱动状态（WindowListener → WindowState.mode/isResizing）。
class WindowService with WindowListener implements WindowBridge {
  WindowService({
    DisplayEnumerator? displayEnumerator,
    DesktopFullscreenAdapter? fullscreenAdapter,
  }) : _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter(),
       _fullscreenAdapter = fullscreenAdapter {
    // D-28: 监听 FullscreenAdapter 状态变化，同步 fullscreen 到 WindowService.mode。
    _fullscreenAdapter?.isFullscreen.addListener(_onFullscreenChanged);
  }

  // ─── Components ───

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();
  final DisplayEnumerator _displayEnumerator;

  /// 全屏适配器 — 非 null 时 fullscreen 操作委托给此适配器 (D-28)。
  final DesktopFullscreenAdapter? _fullscreenAdapter;

  // Importers: app.dart creates WindowService; player_screen.dart uses WindowBridge
  // Affected API: init() uses setBounds, onWindowResize uses _isProgrammaticResize/_skipNextResize
  // User verbatim: "A+B+C+D 实施计划 — setBounds 原子操作 + setAspectRatio 锁定 + 防循环 + 跳过首次回调"
  bool _disposed = false;
  bool _isProgrammaticResize = false; // C: 防止程序化 resize 触发 UI 循环
  bool _skipNextResize = false; // D: 跳过 init 首次 resize 回调

  // ─── Animation constants ───

  static const int _durationWindowResize = 100;
  static const int _durationResizeEnd = 500; // 覆盖 Windows ~300ms 最大化动画

  Timer? _resizeDebounce;
  Timer? _resizeEndTimer;

  // ─── WindowBridge state getters ───

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;

  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;

  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;

  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  // ─── Extended accessors (new API) ───

  /// 窗口状态容器 — 新代码优先使用此接口。
  WindowState get state => _state;

  // ─── Init ───

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 513), // 480 内容高度 + 32px 标题栏 = 16:9 最小比例
    );

    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        final settings = await SettingsStore.load();

        if (settings.windowX != null && settings.windowY != null) {
          final displays = _displayEnumerator.enumerateDisplays();
          final clamped = ScreenUtils.clampToNearestMonitor(
            displays: displays,
            x: settings.windowX!,
            y: settings.windowY!,
            width: settings.windowWidth,
            height: settings.windowHeight,
          );
          // A: setBounds 原子操作 — position+size 一次 SetWindowPos
          await windowManager.setBounds(
            null,
            position: clamped,
            size: Size(settings.windowWidth, settings.windowHeight),
          );
        } else {
          await windowManager.setBounds(
            null,
            size: Size(settings.windowWidth, settings.windowHeight),
          );
          await windowManager.center();
        }

        // D: 跳过 init 首次 resize 回调
        _skipNextResize = true;

        await windowManager.show();
        await windowManager.focus();

        if (settings.isMaximized) await windowManager.maximize();
      }),
    );

    windowManager.addListener(this);
  }

  // ─── FullscreenAdapter state sync (D-28) ───

  /// FullscreenAdapter 状态回调 — 将全屏状态同步到 WindowService.mode。
  ///
  /// 仅在 _fullscreenAdapter 非 null 时生效。
  /// isFullscreen.value = true → mode = fullscreen, false → mode = windowed。
  void _onFullscreenChanged() {
    if (_disposed) return;
    _updateOnUIThread(() {
      final target = _fullscreenAdapter!.isFullscreen.value
          ? WindowMode.fullscreen
          : WindowMode.windowed;
      if (_state.mode.value != target) {
        _state.mode.value = target;
      }
    });
  }

  // ─── WindowListener: OS callbacks drive state ───

  /// 确保 ValueNotifier 更新在 UI 线程执行。
  ///
  /// macOS/Linux 的 WindowListener 回调可能在 platform thread，
  /// 直接更新 ValueNotifier 会触发 notifyListeners() 跨线程崩溃。
  void _updateOnUIThread(VoidCallback update) {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        update();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) => update());
      }
    } catch (_) {
      // 测试环境或 binding 未初始化时直接执行
      update();
    }
  }

  /// 统一的 resize 结束定时器 — 冻结 blur 直到动画完全结束
  void _startResizeEndTimer() {
    _resizeEndTimer?.cancel();
    _updateOnUIThread(() => _state.isResizing.value = true);
    _resizeEndTimer = Timer(
      const Duration(milliseconds: _durationResizeEnd),
      () {
        if (!_disposed) {
          _updateOnUIThread(() => _state.isResizing.value = false);
        }
      },
    );
  }

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    logBridge.d('onWindowMaximize()');
    _startResizeEndTimer(); // 冻结 blur 覆盖整个动画周期
    _updateOnUIThread(() {
      if (_state.mode.value != WindowMode.maximized) {
        _state.mode.value = WindowMode.maximized;
      }
    });
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    logBridge.d('onWindowUnmaximize()');
    _startResizeEndTimer(); // 冻结 blur 覆盖整个动画周期
    _updateOnUIThread(() {
      if (_state.mode.value == WindowMode.maximized) {
        _state.mode.value = WindowMode.windowed;
      }
    });
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    // D: 跳过 init 首次 resize 回调
    if (_skipNextResize) {
      _skipNextResize = false;
      return;
    }
    // C: 程序化 resize 不触发 UI rebuild
    if (_isProgrammaticResize) {
      _isProgrammaticResize = false;
      return;
    }
    _startResizeEndTimer(); // 统一逻辑
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(
      const Duration(milliseconds: _durationWindowResize),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (!_disposed && size != _state.windowSize.value) {
            _updateOnUIThread(() {
              _state.windowSize.value = Size(
                math.max(size.width, 854),
                math.max(size.height, 513),
              );
            });
          }
        });
      },
    );
  }

  @override
  void onWindowClose() {
    logBridge.i('onWindowClose() — saving geometry');
    _resizeDebounce?.cancel();
    _resizeEndTimer?.cancel();
    _saveGeometry().whenComplete(() {
      dispose();
      windowManager.destroy();
    });
  }

  // ─── Commands ───

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed || target == _state.mode.value) return;
    logBridge.i('setMode($target) ← ${_state.mode.value}');

    switch (target) {
      case WindowMode.windowed:
        // D-28: 退出全屏委托给 FullscreenAdapter
        if (_state.mode.value == WindowMode.fullscreen &&
            _fullscreenAdapter != null) {
          // T2: 同步更新 mode — 不等 FullscreenAdapter Left 事件。
          // 与 fullscreen 分支对称，消除 1 帧延迟。
          _state.mode.value = WindowMode.windowed;
          // BUG-03 修正: 退出全屏失败时回滚 mode
          try {
            await _fullscreenAdapter.setFullscreen(false);
          } on Exception catch (e) {
            _state.mode.value = WindowMode.fullscreen;
            debugPrint('[WindowService] fullscreen exit failed: $e');
          }
        } else if (_state.mode.value == WindowMode.maximized) {
          await windowManager.unmaximize();
          // OS 回调 onWindowUnmaximize 驱动 mode
        }
      case WindowMode.maximized:
        await windowManager.maximize();
      // OS 回调 onWindowMaximize 驱动 mode
      case WindowMode.minimized:
        await windowManager.minimize();
      // OS 回调 onWindowMinimize 驱动 mode
      case WindowMode.fullscreen:
        // D-28: 进入全屏委托给 FullscreenAdapter (D-31: 不在 WindowService 加 flag)
        if (_fullscreenAdapter != null) {
          // T2: 同步更新 mode — 不等 FullscreenAdapter Entered 事件。
          // _updateOnUIThread 在非 idle 阶段用 addPostFrameCallback 延迟 1 帧，
          // 导致 DragToResizeArea 以 windowed 布局渲染到全屏窗口 = 布局错位。
          // 先设 mode，Adapter 事件到达时已是目标值，不触发额外 rebuild。
          _state.mode.value = WindowMode.fullscreen;
          // BUG-03 修正: 全屏失败时回滚 mode，避免状态不一致
          try {
            await _fullscreenAdapter.setFullscreen(true);
          } on Exception catch (e) {
            _state.mode.value = WindowMode.windowed;
            debugPrint('[WindowService] fullscreen enter failed: $e');
          }
        }
    }
  }

  @override
  Future<void> setAspectRatio(double ratio) async {
    await windowManager.setAspectRatio(ratio);
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    _state.isAlwaysOnTop.value = value;
    await SettingsStore.saveIsAlwaysOnTop(value);
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  // ─── Geometry persistence ───

  Future<void> _saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _persistence.saveWindowGeometry(
        x: pos.dx,
        y: pos.dy,
        width: size.width,
        height: size.height,
        isMaximized: _state.mode.value.isMaximized,
      );
    } catch (e, st) {
      logBridge.e('[WindowService._saveGeometry] $e\n$st');
    }
  }

  // ─── Lifecycle ───

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeDebounce?.cancel();
    _resizeEndTimer?.cancel();
    _fullscreenAdapter?.isFullscreen.removeListener(_onFullscreenChanged);
    _fullscreenAdapter?.dispose();
    _state.dispose();
    _persistence.dispose();
    windowManager.removeListener(this);
  }
}
