import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../ui/theme/tokens.dart';
import '../persistence/settings_store.dart';
import '../utils/log.dart';
import 'window_geometry_store.dart';

/// 窗口管理服务 — 状态 + 监听者 + 命令 + 几何协调。
class WindowService with WindowListener {
  WindowService();

  late final WindowGeometryStore _geometry = WindowGeometryStore(this);

  // ─── Public state ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(1280, 720));

  bool _disposed = false;
  Timer? _resizeDebounce;

  // ─── Fullscreen animation ───
  bool _isAnimating = false;
  Timer? _fsAnimTimer;

  void _safeSet<T>(ValueNotifier<T> notifier, T value) {
    if (!_disposed) notifier.value = value;
  }

  // ─── Init ───

  /// 初始化窗口 — 在 main() 中 runApp() 之前调用。
  Future<void> init() async {
    logBridge.d('[WindowService.init] start');
    await windowManager.ensureInitialized();
    logBridge.d('[WindowService.init] ensureInitialized done');

    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 480),
    );

    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        logBridge.d('[WindowService.waitUntilReadyToShow] callback entered');

        final settings = await SettingsStore.load();
        logBridge.d(
          '[WindowService.waitUntilReadyToShow] settings loaded: ${settings.windowWidth}×${settings.windowHeight}, '
          'max=${settings.isMaximized}, fs=${settings.isFullscreen}',
        );

        if (settings.isFullscreen) {
          logBridge.d(
            '[WindowService.waitUntilReadyToShow] clearing stale fullscreen flag',
          );
          await SettingsStore.saveIsFullscreen(false);
        }

        await _geometry.restoreGeometry(settings);
        logBridge.d('[WindowService.waitUntilReadyToShow] geometry restored');

        await windowManager.show();
        await windowManager.focus();
        logBridge.d(
          '[WindowService.waitUntilReadyToShow] window shown + focused',
        );

        if (settings.isMaximized) {
          logBridge.d(
            '[WindowService.waitUntilReadyToShow] restoring maximized state',
          );
          await windowManager.maximize();
        }
        logBridge.d('[WindowService.init] complete');
      }),
    );

    windowManager.addListener(this);
    logBridge.d('[WindowService.init] listener registered');
  }

  // ─── WindowListener ───

  @override
  void onWindowMaximize() {
    logBridge.d('[WindowService.onWindowMaximize]');
    if (!isMaximized.value) _safeSet(isMaximized, true);
  }

  @override
  void onWindowUnmaximize() {
    logBridge.d('[WindowService.onWindowUnmaximize]');
    if (isMaximized.value) _safeSet(isMaximized, false);
  }

  @override
  void onWindowEnterFullScreen() {
    logBridge.d(
      '[WindowService.onWindowEnterFullScreen] current=${isFullscreen.value}',
    );
    if (!isFullscreen.value) _safeSet(isFullscreen, true);
  }

  @override
  void onWindowLeaveFullScreen() {
    logBridge.d(
      '[WindowService.onWindowLeaveFullScreen] current=${isFullscreen.value}',
    );
    if (isFullscreen.value) _safeSet(isFullscreen, false);
  }

  @override
  void onWindowResize() {
    if (_disposed || _isAnimating) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: Tokens.durationWindowResize), () {
      if (_disposed) return;
      windowManager.getSize().then((size) {
        if (!_disposed) {
          logBridge.d(
            '[WindowService.onWindowResize] ${size.width.toInt()}×${size.height.toInt()}',
          );
          windowSize.value = size;
        }
      });
    });
  }

  @override
  void onWindowClose() {
    logBridge.d(
      '[WindowService.onWindowClose] saving geometry then destroying',
    );
    _resizeDebounce?.cancel();
    _disposed = true;
    _geometry.saveGeometry().whenComplete(() => windowManager.destroy());
  }

  // ─── Commands ───

  Future<void> _runWindowAction(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Exception catch (e) {
      logBridge.w('[WindowService.$label] FAILED: $e');
    }
  }

  Future<void> setFullscreen(bool value) async {
    logBridge.d(
      '[WindowService.setFullscreen] value=$value current=${isFullscreen.value}',
    );
    if (value == isFullscreen.value || _isAnimating) return;

    try {
      _isAnimating = true;
      _fsAnimTimer?.cancel();
      await windowManager.setFullScreen(value);
      if (value) await SettingsStore.saveIsFullscreen(true);
      if (!_disposed) isFullscreen.value = value;
      _fsAnimTimer = Timer(
        const Duration(milliseconds: Tokens.durationFullscreenAnim),
        () {
          _isAnimating = false;
          if (!value && !_disposed) SettingsStore.saveIsFullscreen(false);
        },
      );
    } on Exception catch (e) {
      _isAnimating = false;
      logBridge.w('[WindowService.setFullscreen] FAILED: $e');
    }
  }

  Future<void> enterFullscreen() => setFullscreen(true);
  Future<void> exitFullscreen() => setFullscreen(false);

  Future<void> setAlwaysOnTop(bool value) async {
    logBridge.d('[WindowService.setAlwaysOnTop] value=$value');
    await _runWindowAction('setAlwaysOnTop', () async {
      await windowManager.setAlwaysOnTop(value);
      isAlwaysOnTop.value = value;
      await SettingsStore.saveIsAlwaysOnTop(value);
    });
  }

  Future<void> minimize() async {
    logBridge.d('[WindowService.minimize]');
    await _runWindowAction('minimize', windowManager.minimize);
  }

  Future<void> maximize() async {
    logBridge.d('[WindowService.maximize]');
    await _runWindowAction('maximize', () async {
      await windowManager.maximize();
      isMaximized.value = true;
    });
  }

  Future<void> restore() async {
    logBridge.d('[WindowService.restore]');
    await _runWindowAction('restore', () async {
      await windowManager.unmaximize();
      isMaximized.value = false;
    });
  }

  Future<void> close() async {
    logBridge.d('[WindowService.close]');
    await _runWindowAction('close', windowManager.close);
  }

  Future<void> startDragging() async {
    logBridge.d('[WindowService.startDragging]');
    await _runWindowAction('startDragging', windowManager.startDragging);
  }

  // ─── Lifecycle ───

  void dispose() {
    logBridge.d('[WindowService.dispose]');
    _disposed = true;
    _resizeDebounce?.cancel();
    _fsAnimTimer?.cancel();
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
    windowManager.removeListener(this);
  }
}
