import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../bridge/win32/native_fullscreen_bridge.dart';
import '../diagnostics/kernel_logger.dart';
import '../persistence/window_persistence.dart';
import 'window_bridge.dart';
import 'window_constants.dart';
import 'window_mode_coordinator.dart';
import 'window_persistence_coordinator.dart';
import 'window_resize_coordinator.dart';
import 'window_service_state.dart';
import 'window_ui_thread.dart';

export 'window_bridge.dart';
export 'window_constants.dart';
export 'window_mode_coordinator.dart';
export 'window_persistence_coordinator.dart';
export 'window_resize_coordinator.dart';
export 'window_service_state.dart';
export 'window_ui_thread.dart';

/// 日志门面 — WindowService 共用。
final _log = KernelLogger.I;

/// Window management service - thin coordinator combining responsibility components.
class WindowService with WindowListener implements WindowBridge {
  /// 创建 WindowService。
  ///
  /// 创建窗口服务。
  WindowService({WindowPersistence? persistence})
    : _persistence = persistence ?? WindowPersistence();

  final WindowPersistence _persistence;
  final WindowServiceState _state = WindowServiceState();
  WindowResizeCoordinator? _resizeCoordinator;
  late final WindowPersistenceCoordinator _persistenceCoordinator =
      WindowPersistenceCoordinator(
        state: _state,
        persistence: _persistence,
        readPosition: windowManager.getPosition,
        log: (message, error, stackTrace) =>
            _log.w('$message: $error\n$stackTrace'),
      );

  bool _disposed = false;
  bool _isClosing = false;
  bool _initialized = false;
  Future<void>? _initOperation;

  /// 原生全屏 FFI 桥 — 物理全屏动作的唯一执行者（方案 A）。
  ///
  /// media_kit 的 utils.cc 退出时以"标准窗口假设"恢复样式，会漂移
  /// window_manager hidden/frameless 样式位；本桥以进入时快照精确还原。
  final NativeFullscreenBridge _nativeFullscreen = NativeFullscreenBridge();

  late final WindowModeCoordinator _modeCoordinator = WindowModeCoordinator(
    state: _state,
    maximize: windowManager.maximize,
    unmaximize: windowManager.unmaximize,
    // 方案 A：全屏物理动作在语义队列内收编到本桥 — 无论 UI 路径（F 键/
    // 双击/按钮）走哪条，setMode 的全屏分支都是唯一触发点。
    setNativeFullscreen: (enter) =>
        enter ? _nativeFullscreen.enter() : _nativeFullscreen.exit(),
    waitForInitialization: () async {
      final operation = _initOperation;
      if (operation != null) await operation;
    },
    log: _log.i,
  );
  int _resizeSuppressionGeneration = 0;
  int _activeResizeSuppression = 0;

  /// 关窗路径中单个平台命令的硬上限 — hide/persist/destroy 中任何一个
  /// channel 调用卡住时，超时后继续推进，绝不让用户面对滞留窗口。
  ///
  /// 学自 BlueBubbles 的关窗策略:窗口先消失、清理放后台。本项目无系统
  /// 托盘，窗口必须真正销毁，因此用 timeout 兜底替代其 exit(0) 硬杀。
  static const _closeCommandTimeout = Duration(milliseconds: 800);

  /// resize 防抖延迟 — 500ms 内无新 resize 事件才更新 windowSize。
  Future<void>? _closeOperation;

  /// 当前是否全屏 — 从 mode 派生，单一数据源。
  @override
  bool get isFullscreen => _state.mode.value.isFullscreen;

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;
  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;
  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;
  @override
  ValueNotifier<int> get resizeSessionId => _state.resizeSessionId;
  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  @override
  Future<void> init() {
    if (_disposed || _initialized) return Future<void>.value();
    return _initOperation ??= _initOnce().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _initOperation = null;
      _log.e('[WindowService.init] $error\n$stackTrace');
      throw error;
    });
  }

  Future<void> _initOnce() async {
    var listenerAdded = false;
    try {
      // windowManager.ensureInitialized() is owned by main.dart.
      // 拦截原生关闭事件，确保异步窗口状态持久化完成后再销毁窗口。
      await windowManager.setPreventClose(true);
      const options = WindowOptions(
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        minimumSize: minimumWindowSize,
      );
      final ready = Completer<void>();
      // waitUntilReadyToShow 只接受同步回调；通过 Completer 将异步恢复结果
      // 传递给 init()，确保调用方等待到窗口真正 show/focus 完成。
      await windowManager.waitUntilReadyToShow(options, () {
        unawaited(_completeReadyAfterInit(ready));
      });
      if (_disposed) return;
      windowManager.addListener(this);
      listenerAdded = true;
      _ensureResizeCoordinator();
      await ready.future;
      if (_disposed) return;
      _initialized = true;
    } on Exception {
      _cleanupFailedInit(listenerAdded: listenerAdded);
      rethrow;
    } on Error {
      // 清理资源后继续抛出编程错误，避免把不可恢复错误伪装成初始化失败。
      _cleanupFailedInit(listenerAdded: listenerAdded);
      rethrow;
    }
  }

  Future<void> _completeReadyAfterInit(Completer<void> ready) async {
    try {
      await _runInitWindowSafely();
      if (!ready.isCompleted) ready.complete();
    } on Object catch (error, stackTrace) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
    }
  }

  /// 清理初始化失败后已注册的资源，使后续重试不会叠加监听器。
  void _cleanupFailedInit({required bool listenerAdded}) {
    _resizeCoordinator?.dispose();
    _resizeCoordinator = null;
    if (listenerAdded) windowManager.removeListener(this);
    _initialized = false;
  }

  /// 窗口初始化 — 在 waitUntilReadyToShow 回调内 fire-and-forget 触发。
  ///
  /// 提取为 async 方法以满足回调期望同步 VoidCallback 的契约
  /// (DCM avoid-passing-async-when-sync-expected)。纯 async 形态重组,
  /// 信号源逻辑(frameless 设置 / isResizing)一字未改。
  Future<void> _runInitWindowSafely() async {
    try {
      await _initWindow();
    } on Exception catch (error, stackTrace) {
      _log.e('[WindowService._initWindow] $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> _initWindow() async {
    // 保持 hidden title bar 配置，不再切换 frameless 样式；Windows runner
    // 在 WM_NCHITTEST 中统一四边 8px 判定区（含插件未覆盖的顶部），
    // 命中 HT* 后交给系统原生 resize loop。
    if (_disposed) return;
    // Restore only validated geometry; corrupt preferences fall back to 1280×752.
    final persisted = await _persistence.load();
    if (_disposed) return;
    if (persisted.position case final position?) {
      await windowManager.setBounds(
        Rect.fromLTWH(
          position.dx,
          position.dy,
          persisted.size.width,
          persisted.size.height,
        ),
      );
    } else {
      // 首次启动或位置损坏时仍应用已校验的尺寸，并交给平台居中，
      // 避免依赖不可预测的默认窗口几何。
      await windowManager.setSize(persisted.size);
      await windowManager.center();
    }
    if (_disposed) return;
    await windowManager.setAlwaysOnTop(persisted.alwaysOnTop);
    if (_disposed) return;
    _state.windowSize.value = persisted.size;
    _state.isAlwaysOnTop.value = persisted.alwaysOnTop;
    _state.mode.value = persisted.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
    _activeResizeSuppression = ++_resizeSuppressionGeneration;
    await windowManager.show();
    if (_disposed) return;
    if (persisted.isMaximized) {
      await windowManager.maximize();
      if (_disposed) return;
    }
    await windowManager.focus();
  }

  void _updateOnUIThread(VoidCallback update) {
    updateOnUIThread(
      update,
      warn: (error, stackTrace) =>
          _log.w('[WindowService._updateOnUIThread] $error\n$stackTrace'),
    );
  }

  void _ensureResizeCoordinator() {
    _resizeCoordinator ??= WindowResizeCoordinator(
      state: _state,
      readSize: windowManager.getSize,
      persistSize: (size) => _persistenceCoordinator.save(size: size),
      logger: _log,
    );
  }

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    _log.d('onWindowMaximize()');
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
    _updateOnUIThread(_modeCoordinator.onNativeMaximize);
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    _log.d('onWindowUnmaximize()');
    if (_modeCoordinator.fullscreenIntent) return;
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
    _updateOnUIThread(_modeCoordinator.onNativeUnmaximize);
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    if (_activeResizeSuppression != 0) {
      _activeResizeSuppression = 0;
      return;
    }
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
  }

  @override
  void onWindowClose() {
    if (_disposed || _isClosing) return;
    _log.i('onWindowClose()');
    _isClosing = true;
    _resizeCoordinator?.dispose();
    // Finish the preference write before destroying the native window.
    unawaited(
      _closeWindowOperation().catchError((Object error, StackTrace stackTrace) {
        _log.e('[WindowService.onWindowClose] $error\n$stackTrace');
      }),
    );
  }

  Future<void> _closeWindowOperation() {
    return _closeOperation ??= _persistThenDestroy();
  }

  Future<void> _persistThenDestroy() async {
    // 1) hide-first:窗口先视觉消失（BlueBubbles 模式），后续持久化与
    //    销毁在"看不见"的状态下完成。hide 本身也可能卡 channel — 加
    //    超时兜底，超时后继续走持久化。
    await _runCloseCommand('hide', windowManager.hide);
    // 2) 仅等待轻量的偏好设置写入（含超时兜底），确保下次启动仍能
    //    恢复最后稳定的窗口几何。
    await _runCloseCommand(
      'persist',
      () => _saveWindowState(size: _state.windowSize.value),
    );
    // 3) 销毁窗口。失败仅记录 — dispose() 仍会执行，服务进入终态。
    try {
      await _runCloseCommand('destroy', windowManager.destroy);
    } on Object catch (error, stackTrace) {
      _log.e(
        '[WindowService._persistThenDestroy] destroy failed: $error\n$stackTrace',
      );
    } finally {
      dispose();
    }
  }

  /// 执行关窗路径中的单个平台命令，附带超时兜底。
  ///
  /// 超时不会取消底层调用（MethodChannel 无法真正取消），只是不再等待
  /// 它完成 — 卡住的命令被记入日志后放任其自生自灭。
  Future<void> _runCloseCommand(
    String label,
    Future<void> Function() command,
  ) async {
    try {
      await command().timeout(_closeCommandTimeout);
    } on TimeoutException {
      _log.w(
        '[WindowService.close] "$label" timed out after '
        '$_closeCommandTimeout — continuing anyway',
      );
    } on Object catch (error, stackTrace) {
      _log.e('[WindowService.close] "$label" failed: $error\n$stackTrace');
    }
  }

  /// Saves the current settled geometry without letting persistence failures affect UI.
  Future<void> _saveWindowState({Size? size}) =>
      _persistenceCoordinator.save(size: size);

  @override
  Future<void> setMode(WindowMode target) => _modeCoordinator.setMode(target);

  @override
  void enterNativeFullscreen() {
    if (_disposed) return;
    _modeCoordinator.enqueue(() async {
      if (_disposed) return;
      _nativeFullscreen.enter();
    });
  }

  @override
  void exitNativeFullscreen() {
    if (_disposed) return;
    _modeCoordinator.enqueue(() async {
      if (_disposed) return;
      _nativeFullscreen.exit();
    });
  }

  @override
  Future<void> setAlwaysOnTop(bool value) {
    return _modeCoordinator.enqueue(() => _setAlwaysOnTopSerialized(value));
  }

  Future<void> _setAlwaysOnTopSerialized(bool value) async {
    if (_disposed || value == _state.isAlwaysOnTop.value) return;
    await windowManager.setAlwaysOnTop(value);
    if (_disposed) return;
    _state.isAlwaysOnTop.value = value;
    await _saveWindowState();
  }

  @override
  Future<void> minimize() async {
    if (_disposed) return;
    await windowManager.minimize();
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    if (_isClosing) {
      await (_closeOperation ?? Future<void>.value());
      return;
    }
    _isClosing = true;
    _resizeCoordinator?.dispose();
    await _closeWindowOperation();
  }

  @override
  Future<void> startDragging() async {
    if (_disposed) return;
    await windowManager.startDragging();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // 先使 resize coordinator 的延迟回调失效，再释放状态 notifier。
    _resizeCoordinator?.dispose();
    _state.dispose();
    windowManager.removeListener(this);
  }
}
