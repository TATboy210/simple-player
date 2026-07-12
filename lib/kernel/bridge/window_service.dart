import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'display_enumerator.dart';
import 'fullscreen_driver.dart';
import 'platform/linux_fullscreen_driver.dart';
import 'platform/macos_fullscreen_driver.dart';
import 'platform/windows_fullscreen_driver.dart';
import 'win32/win32_display_enumerator.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';

/// Window management service - thin coordinator combining responsibility components.
class WindowService with WindowListener implements WindowBridge {
  /// 创建 WindowService。
  ///
  /// [driver] 可选注入全屏驱动（测试用），默认通过 [_createDriver] 自动创建。
  /// [displayEnumerator] 可选注入显示器枚举器，默认使用 Win32DisplayAdapter。
  WindowService({
    DisplayEnumerator? displayEnumerator,
    FullscreenDriver? driver,
  }) : _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter(),
       _fullscreenDriver = driver ?? _createDriver() {
    _fullscreenDriver?.onNativeStateChanged = _onNativeFullScreenChanged;
  }

  /// 根据当前平台创建合适的 FullscreenDriver。
  ///
  /// - Windows: WindowsFullscreenDriver (Win32 FFI)，HWND 无效时返回 null
  /// - macOS: MacosFullscreenDriver (fullscreen_window 插件)
  /// - Linux: LinuxFullscreenDriver (fullscreen_window 插件)
  /// - 其他: 返回 null（不支持全屏）
  static FullscreenDriver? _createDriver() {
    if (Platform.isWindows) {
      try {
        final driver = WindowsFullscreenDriver();
        final api = driver.apiForTesting;
        final hwnd = api.getFlutterHwnd();
        if (hwnd == 0 || !api.isWindow(hwnd)) {
          debugPrint('[WindowService] HWND invalid ($hwnd), no fullscreen');
          return null;
        }
        return driver;
      } on Exception catch (e) {
        debugPrint('[WindowService] WindowsFullscreenDriver init failed: $e');
        return null;
      }
    }
    if (Platform.isMacOS) return MacosFullscreenDriver();
    if (Platform.isLinux) return LinuxFullscreenDriver();
    debugPrint('[WindowService] unsupported platform, no fullscreen');
    return null;
  }

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();
  final DisplayEnumerator _displayEnumerator;
  final FullscreenDriver? _fullscreenDriver;

  bool _disposed = false;
  bool _isProgrammaticResize = false;
  bool _skipNextResize = false;

  /// resize 防抖延迟 — 500ms 内无新 resize 事件才更新 windowSize。
  static const int _resizeDebounceMs = 500;

  Timer? _resizeTimer;

  /// 当前是否全屏 — 从 mode 派生，单一数据源。
  @override
  bool get isFullscreen => _state.mode.value.isFullscreen;

  final Map<int, _RestoreSnapshot> _restoreSnapshots = {};

  /// 单一确认 Completer — 替代 _confirmByWindowId map + 20x 轮询。
  Completer<bool>? _confirmationCompleter;

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;
  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;
  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;
  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  WindowState get state => _state;

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 513),
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
        _skipNextResize = true;
        await windowManager.show();
        await windowManager.focus();
        if (settings.isMaximized) await windowManager.maximize();
      }),
    );
    windowManager.addListener(this);
  }

  /// 原生全屏状态变更回调 — 完成确认 Completer 或更新 mode。
  void _onNativeFullScreenChanged(int windowId, bool isFullscreen) {
    if (_disposed) return;
    final completer = _confirmationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
      return;
    }
    _updateOnUIThread(() {
      final target = isFullscreen ? WindowMode.fullscreen : WindowMode.windowed;
      if (_state.mode.value != target) {
        _state.mode.value = target;
      }
    });
  }

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
      update();
    }
  }

  /// 单一 resize 定时器 — 合并 isResizing 标记和 windowSize 更新。
  void _startResizeTimer() {
    _resizeTimer?.cancel();
    _updateOnUIThread(() => _state.isResizing.value = true);
    _resizeTimer = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (!_disposed && size != _state.windowSize.value) {
            _updateOnUIThread(() {
              _state.windowSize.value = Size(
                math.max(size.width, 854),
                math.max(size.height, 513),
              );
              _state.isResizing.value = false;
            });
          }
        });
      },
    );
  }

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    logBridge.d('onWindowMaximize()');
    _startResizeTimer();
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
    _startResizeTimer();
    _updateOnUIThread(() {
      if (_state.mode.value == WindowMode.maximized) {
        _state.mode.value = WindowMode.windowed;
      }
    });
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    if (_skipNextResize) { _skipNextResize = false; return; }
    if (_isProgrammaticResize) { _isProgrammaticResize = false; return; }
    _startResizeTimer();
  }

  @override
  void onWindowClose() {
    logBridge.i('onWindowClose() - saving geometry');
    _resizeTimer?.cancel();
    _saveGeometry().whenComplete(() {
      dispose();
      windowManager.destroy();
    });
  }

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed || target == _state.mode.value) return;
    logBridge.i('setMode($target) <- ${_state.mode.value}');
    switch (target) {
      case WindowMode.windowed:
        if (_state.mode.value == WindowMode.fullscreen &&
            _fullscreenDriver != null) {
          _state.mode.value = WindowMode.windowed;
          final result = await _handleLeave(0);
          if (result is FullscreenFailure) {
            _state.mode.value = WindowMode.fullscreen;
          }
        } else if (_state.mode.value == WindowMode.maximized) {
          await windowManager.unmaximize();
        }
      case WindowMode.maximized:
        await windowManager.maximize();
      case WindowMode.minimized:
        await windowManager.minimize();
      case WindowMode.fullscreen:
        if (_fullscreenDriver != null) {
          _state.mode.value = WindowMode.fullscreen;
          final result = await _handleEnter(0);
          if (result is FullscreenFailure) {
            _state.mode.value = WindowMode.windowed;
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

  // ─── Fullscreen enter/leave (merged from DesktopFullscreenAdapter) ───

  /// 进入全屏 — 返回 [FullscreenResult] 表示操作结果。
  ///
  /// 快速路径 (supportsFastPath) 直接操作，否则通过三级确认链等待原生回调。
  Future<FullscreenResult> _handleEnter(int windowId) async {
    final driver = _fullscreenDriver;
    if (driver == null) return const FullscreenFailure();
    if (_state.mode.value != WindowMode.fullscreen) { await _captureRestoreSnapshot(windowId); }
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (driver.supportsFastPath) {
        await driver.enterFullscreenFast(displayId: 0);
        return const FullscreenSuccess();
      }
      await driver.enterFullscreen(displayId: 0);
      final confirmed = await _waitForConfirmation(true);
      if (confirmed) {
        return const FullscreenSuccess();
      } else {
        await _applyDesync();
        return const FullscreenFailure();
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] fullscreen enter failed: $e');
      return const FullscreenFailure();
    }
  }

  /// 退出全屏 — 返回 [FullscreenResult] 表示操作结果。
  Future<FullscreenResult> _handleLeave(int windowId) async {
    final driver = _fullscreenDriver;
    if (driver == null) return const FullscreenFailure();
    try {
      if (driver.supportsFastPath) {
        await driver.leaveFullscreenFast();
        await _restoreFromSnapshot(windowId);
        return const FullscreenSuccess();
      }
      await driver.leaveFullscreen();
      final confirmed = await _waitForConfirmation(false);
      if (confirmed) {
        await _restoreFromSnapshot(windowId);
        return const FullscreenSuccess();
      } else {
        await _applyDesync();
        return const FullscreenFailure();
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] fullscreen leave failed: $e');
      return const FullscreenFailure();
    }
  }

  Future<void> _applyDesync() async {
    final driver = _fullscreenDriver;
    if (driver == null) return;
    final actual = await driver.queryFullscreen();
    debugPrint('[WindowService] desync detected, correcting to $actual');
    _updateOnUIThread(() {
      _state.mode.value = actual ? WindowMode.fullscreen : WindowMode.windowed;
    });
  }

  Future<void> _captureRestoreSnapshot(int windowId) async {
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final maximized = await windowManager.isMaximized();
      _restoreSnapshots[windowId] = _RestoreSnapshot(
        position: position, size: size, isMaximized: maximized,
      );
    } on Exception catch (e) {
      debugPrint('[WindowService] captureRestoreSnapshot failed: $e');
    }
  }

  Future<void> _restoreFromSnapshot(int windowId) async {
    final snapshot = _restoreSnapshots.remove(windowId);
    if (snapshot == null) return;
    if (snapshot.isMaximized) {
      await windowManager.maximize();
      return;
    }
    if (snapshot.position != Offset.zero || snapshot.size != Size.zero) {
      try {
        await windowManager.setBounds(
          null, position: snapshot.position, size: snapshot.size,
        );
      } on Exception catch (_) {
        await windowManager.setBounds(null, size: snapshot.size);
        await windowManager.center();
      }
    }
  }

  /// 等待全屏确认 — 原生回调优先，超时后单次查询兜底。
  Future<bool> _waitForConfirmation(bool expectedFullscreen) async {
    final driver = _fullscreenDriver;
    if (driver == null) return false;
    _confirmationCompleter = Completer<bool>();
    try {
      final confirmed = await _confirmationCompleter!.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (confirmed) return true;
    } finally {
      _confirmationCompleter = null;
    }
    // 超时后单次查询 — 替代 20x 轮询
    final actual = await driver.queryFullscreen();
    return actual == expectedFullscreen;
  }

  Future<void> _saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _persistence.saveWindowGeometry(
        x: pos.dx, y: pos.dy,
        width: size.width, height: size.height,
        isMaximized: _state.mode.value.isMaximized,
      );
    } catch (e, st) {
      logBridge.e('[WindowService._saveGeometry] $e\n$st');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _fullscreenDriver?.onNativeStateChanged = null;
    _fullscreenDriver?.dispose();
    _restoreSnapshots.clear();
    if (_confirmationCompleter != null && !_confirmationCompleter!.isCompleted) {
      _confirmationCompleter!.complete(false);
    }
    _confirmationCompleter = null;
    _state.dispose();
    _persistence.dispose();
    windowManager.removeListener(this);
  }
}

final class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.position,
    required this.size,
    this.isMaximized = false,
  });
  final Offset position;
  final Size size;
  final bool isMaximized;
}
