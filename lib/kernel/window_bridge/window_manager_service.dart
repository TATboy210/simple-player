import 'dart:async';
import 'dart:io' show exit;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
  /// 创建窗口服务。[exitOnClose] 注入 seam — 关窗终点的进程终止调用，
  /// 生产绑定 dart:io exit；测试注入 no-op 避免 test runner 被杀。
  WindowService({
    WindowPersistence? persistence,
    void Function(int code)? exitOnClose,
  }) : _persistence = persistence ?? WindowPersistence(),
       _exitOnClose = exitOnClose ?? exit;

  final WindowPersistence _persistence;

  /// 关窗终点的进程终止调用（见 [_persistThenDestroy] 第 4 步）。
  final void Function(int code) _exitOnClose;
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

  /// 关窗持久化窗口监听器 (v0.0.6.2) — 组合根经 [addClosingListener] 注册
  /// 应用级退出落盘（播放列表断点等）; 本类只管时序, 不感知业务语义.
  final List<Future<void> Function()> _closingListeners = [];
  late final WindowModeCoordinator _modeCoordinator = WindowModeCoordinator(
    state: _state,
    maximize: windowManager.maximize,
    unmaximize: windowManager.unmaximize,
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
      // BB 同款（2026-09-06 用户裁决）：window_manager 在 Windows 上不碰
      // 标题栏/边框——bitsdojo 的 BDW_CUSTOM_FRAME 已接管 NCCALCSIZE
      // （return 0，自绘标题栏形态 + 四边等宽缩放），两个插件都改 NCCALCSIZE
      // 会打架（window_manager hidden 分支的 8px 内缩会重新引入白边）。
      const options = WindowOptions(
        backgroundColor: Colors.transparent,
        windowButtonVisibility: false,
        minimumSize: minimumWindowSize,
      );
      // 最小尺寸双通道同步：bitsdojo 的 WM_GETMINMAXINFO hook 无条件
      // return 0，会吞掉 window_manager 的 setMinimumSize（其 min_size
      // 默认 {0,0} 即无下限）。两侧设同一值后，无论 hook 先后顺序如何，
      // 854×480 下限都确定生效。
      doWhenWindowReady(() => appWindow.minSize = minimumWindowSize);
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
    // frame 视觉与边缘命中归 bitsdojo 的 BDW_CUSTOM_FRAME（main.cpp 一行
    // 接线）：原生接管 NCCALCSIZE return 0/四边等宽 WM_NCHITTEST，本服务
    // 专注几何/事件/置顶等窗口管理语义。
    if (_disposed) return;
    // Restore only validated geometry; corrupt preferences fall back to 720p.
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
    // v0.0.4 空白窗口修复：show/maximize/focus 从 init 拆出至 [reveal] —
    // init 在 runApp 之前以隐藏态完成几何恢复，组合根待首帧栅格化后亮窗，
    // 窗口出现即带完整首帧内容（此前 show 先于 runApp，用户看到数百毫秒
    // 空白窗口）。
  }

  /// 亮窗 — 首帧栅格化后由组合根调用（v0.0.4 空白窗口修复）。
  ///
  /// 补上 init 拆出的可见性收尾：show + 条件 maximize（以当前 mode 为准，
  /// 恢复路径已在 [_initWindow] 同步持久化态）+ focus。init 失败路径
  /// （组合根降级 show 已直接亮窗）再调用本方法无害：show 幂等，
  /// maximize/focus 重复无副作用。
  Future<void> reveal() async {
    if (_disposed) return;
    await windowManager.show();
    if (_disposed) return;
    if (_state.mode.value.isMaximized) {
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
    //    退出在"看不见"的状态下完成。hide 本身也可能卡 channel — 加
    //    超时兜底，超时后继续走持久化。
    await _runCloseCommand('hide', windowManager.hide);
    // 2) 仅等待轻量的偏好设置写入（含超时兜底），确保下次启动仍能
    //    恢复最后稳定的窗口几何。await 返回即数据已安全落盘
    //    （shared_preferences 平台实现同步写入后应答）。
    await _runCloseCommand(
      'persist',
      () => _saveWindowState(size: _state.windowSize.value),
    );
    // 2.5) 应用级退出落盘 (v0.0.6.2) — 组合根经 addClosingListener 注册
    //      （播放列表断点等）。List.of 快照迭代防遍历中变更; 单条复用
    //      _closeCommandTimeout 兜底, 失败记日志后继续, 绝不阻塞退出。
    for (final listener in List.of(_closingListeners)) {
      await _runCloseCommand('closing-listener', listener);
    }
    // 3) 销毁窗口 — fire 不等：destroy 的意义只是触发平台侧 WM_DESTROY
    //    链，而下一步 exit(0) 会瞬时终止进程（OS 收尾销毁所有窗口），
    //    等待它只会平添滞留。失败仅记录。
    unawaited(
      _runCloseCommand('destroy', windowManager.destroy).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _log.e(
          '[WindowService._persistThenDestroy] destroy failed: '
          '$error\n$stackTrace',
        );
      }),
    );
    dispose();
    // 4) exit(0) 立即终止进程（BB 同款硬杀）：destroy 触发消息循环退出后，
    //    wWinMain 返回时 CRT 仍需等待 Flutter 引擎线程 / libmpv 渲染与
    //    音频线程收尾 — 这就是"窗口已消失但进程滞留"的根源。此刻窗口已
    //    不可见、窗口状态已落盘，进程没有存续价值，直接终止，跳过引擎
    //    与线程的清理等待。播放器无跨进程状态/锁文件，硬杀无副作用。
    //    测试注入 [_exitOnClose] seam 拦截，避免杀掉 test runner。
    _exitOnClose(0);
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
  void Function() addClosingListener(Future<void> Function() listener) {
    _closingListeners.add(listener);
    // 移除函数幂等 — remove 对不存在元素是 no-op, 重复调用安全.
    return () => _closingListeners.remove(listener);
  }

  @override
  Future<void> startDragging() async {
    // 标题栏拖动（窗口移动）走插件 startDragging——单包后 frame 命中
    // （FrameController）与窗口移动（startDragging）同源，无双包抢权问题。
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
