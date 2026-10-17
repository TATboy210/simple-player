import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import '../bridge/win32/sizemove_bridge.dart';
import '../diagnostics/kernel_logger.dart';
import '../persistence/window_persistence.dart';
import 'window_bridge.dart';
import 'window_constants.dart';
import 'native_window_host.dart';
import 'nativeapi_window_host.dart';
import 'window_mode_coordinator.dart';
import 'window_persistence_coordinator.dart';
import 'window_resize_coordinator.dart';
import 'window_service_state.dart';
import 'window_ui_thread.dart';

export 'window_bridge.dart';
export 'window_constants.dart';
export 'window_mode_coordinator.dart';
export 'window_persistence_coordinator.dart';
export 'native_window_host.dart';
export 'window_resize_coordinator.dart';
export 'window_service_state.dart';
export 'window_ui_thread.dart';

/// 日志门面 — WindowService 共用。
final _log = KernelLogger.I;

/// Window management service - thin coordinator combining responsibility components.
///
/// 平台窗口能力全部经 [NativeWindowHost] 端口（生产: nativeapi 0.5.2,
/// 见 [NativeApiWindowHost]）；本类只承载模式/缩放/持久化/关窗时序语义。
class WindowService implements WindowBridge {
  /// 创建 WindowService。
  ///
  /// 创建窗口服务。[exitOnClose] 注入 seam — 关窗终点的进程终止调用，
  /// 生产绑定 dart:io exit；测试注入 no-op 避免 test runner 被杀。
  /// [host] 注入 seam — 测试传入手写 fake，生产默认 [NativeApiWindowHost]。
  WindowService({
    WindowPersistence? persistence,
    void Function(int code)? exitOnClose,
    NativeWindowHost? host,
  }) : _persistence = persistence ?? WindowPersistence(),
       _exitOnClose = exitOnClose ?? exit,
       _host = host ?? NativeApiWindowHost();

  final WindowPersistence _persistence;

  /// 平台窗口端口 — 唯一的原生窗口依赖。
  final NativeWindowHost _host;

  /// [NativeWindowHost.attach] 成功后置位 — 降级 show 只在已绑定时执行。
  bool _hostAttached = false;

  /// 关窗终点的进程终止调用（见 [_persistThenDestroy] 第 4 步）。
  final void Function(int code) _exitOnClose;
  final WindowServiceState _state = WindowServiceState();
  WindowResizeCoordinator? _resizeCoordinator;
  late final WindowPersistenceCoordinator _persistenceCoordinator =
      WindowPersistenceCoordinator(
        state: _state,
        persistence: _persistence,
        readPosition: _host.getPosition,
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
    maximize: _host.maximize,
    unmaximize: _host.unmaximize,
    waitForInitialization: () async {
      final operation = _initOperation;
      if (operation != null) await operation;
    },
    log: _log.i,
    // 原生全屏走 nativeapi `isFullScreen`（三平台同一入口）。Windows 实现
    // 摘除 WS_CAPTION/WS_THICKFRAME 并铺满显示器、退出时只放回它摘掉的位
    // 并 SetWindowPlacement 恢复进入前几何（含最大化），与隐藏标题栏 frame
    // 状态互不覆盖——原 Win32FullscreenBridge（media_kit utils.cc 移植）
    // 因此删除。
    enterFullscreen: () => _host.setFullScreen(true),
    exitFullscreen: () => _host.setFullScreen(false),
    queryMaximized: _host.isMaximized,
  );

  /// init 隐藏阶段的 resize 抑制 — [_initWindow] 几何恢复会引发一次
  /// WM_SIZE, 置位后 [onWindowResize] 的首个事件被吞掉（消费即清零）。
  /// 261009-rp3: 抑制语义以 [reveal] 为终点 — 若恢复尺寸与当前尺寸相同,
  /// 平台不产生 WM_SIZE, 标志无人消费会滞留, 导致亮窗后首拖被吞。
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
      // nativeapi 绑定当前 runner 窗口: 隐藏标题栏 frame（Windows; 见
      // [NativeApiWindowHost] 库注释）+ 最小尺寸（WM_GETMINMAXINFO 帧尺寸）
      // + 事件监听。关闭请求由宿主同步取消平台默认关闭后转交
      // [onWindowClose]，确保异步持久化完成后再退出。
      await _host.attach(
        minimumSize: minimumWindowSize,
        onEvent: _onNativeEvent,
      );
      listenerAdded = true;
      _hostAttached = true;
      if (_disposed) return;
      _ensureResizeCoordinator();
      await _runInitWindowSafely();
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

  /// 端口事件分发 — 映射回既有 `onWindow*` 回调（测试直接驱动这些方法）。
  void _onNativeEvent(NativeWindowEvent event) {
    switch (event) {
      case NativeWindowMaximized():
        onWindowMaximize();
      case NativeWindowRestored():
        // 平台对「最大化窗口最小化后恢复」也只报 restored — 以宿主当前
        // 状态为准，避免把仍最大化的窗口误记为 windowed。
        unawaited(_onNativeRestored());
      case NativeWindowResized():
        onWindowResize();
      case NativeWindowFocused():
        _log.d('onWindowFocus()');
      case NativeWindowBlurred():
        _log.d('onWindowBlur()');
      case NativeWindowCloseRequested():
        onWindowClose();
    }
  }

  Future<void> _onNativeRestored() async {
    try {
      final maximized = await _host.isMaximized();
      if (maximized) {
        onWindowMaximize();
      } else {
        onWindowUnmaximize();
      }
    } on Object catch (error, stackTrace) {
      _log.w('[WindowService.onRestored] $error\n$stackTrace');
      onWindowUnmaximize();
    }
  }

  /// 清理初始化失败后已注册的资源，使后续重试不会叠加监听器。
  void _cleanupFailedInit({required bool listenerAdded}) {
    _resizeCoordinator?.dispose();
    _resizeCoordinator = null;
    if (listenerAdded) _host.detach();
    _hostAttached = false;
    _initialized = false;
  }

  /// 窗口初始化 — 隐藏态几何恢复（失败记日志后上抛，由 [init] 容纳）。
  Future<void> _runInitWindowSafely() async {
    try {
      await _initWindow();
    } on Exception catch (error, stackTrace) {
      _log.e('[WindowService._initWindow] $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> _initWindow() async {
    // frame 视觉与边缘命中归 nativeapi 隐藏标题栏（见 [_initOnce]），
    // 本服务专注几何/事件/置顶等窗口管理语义。
    if (_disposed) return;
    // Restore only validated geometry; corrupt preferences fall back to 720p.
    final persisted = await _persistence.load();
    if (_disposed) return;
    if (persisted.position case final position?) {
      await _host.setBounds(
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
      await _host.setSize(persisted.size);
      await _host.center();
    }
    if (_disposed) return;
    await _host.setAlwaysOnTop(persisted.alwaysOnTop);
    if (_disposed) return;
    if (persisted.isMaximized) {
      // 隐藏态 maximize: nativeapi 不立即 SW_MAXIMIZE（会提前亮窗），而是
      // 标记「显示即最大化」——runner 首帧 Show 直接以最大化形态出现，
      // 无普通→最大化闪变。
      await _host.maximize();
      if (_disposed) return;
    }
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
    // 261009-rp3 修复: 抑制标志语义只覆盖隐藏 init 阶段 — 亮窗即解除。
    // init 几何恢复若与当前尺寸相同, 平台不产生 WM_SIZE, 消费型标志无人
    // 清零会滞留到亮窗后, 吞掉用户第一次真实拖拽（isResizing 不置位 /
    // windowSize 不更新 / 几何不持久化）。此刻 init 的 setBounds 早已
    // 完成, 其 WM_SIZE 若存在必已送达（被 onWindowResize 消费分支吞掉）
    // 或根本不存在（此处清零防滞留）; 组合根超时兜底保证 reveal 必达。
    _activeResizeSuppression = 0;
    await _host.show();
    if (_disposed) return;
    if (_state.mode.value.isMaximized) {
      await _host.maximize();
      if (_disposed) return;
    }
    await _host.focus();
  }

  /// 降级亮窗 — init/reveal 失败时组合根 best-effort 调用。
  ///
  /// 宿主未绑定（attach 本身失败）时无窗口可操作：runner 首帧回调仍会
  /// 以系统默认形态显示窗口，此处直接返回。
  Future<void> showDegraded() async {
    if (!_hostAttached) return;
    await _host.show();
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
      readSize: _host.getSize,
      persistSize: (size) => _persistenceCoordinator.save(size: size),
      logger: _log,
      sizemoveProbe: _createSizemoveProbe(),
    );
  }

  /// v0.0.9 P0-1 SIZEMOVE 取证接线 — 仅 Debug/Profile 构建（Release 零
  /// 开销，同 ResizeFrameMetrics 的 !kReleaseMode gate 先例）；非 Windows
  /// 平台桥内部也直接返回 null。纯观测不改任何窗口行为。
  SizemoveProbe? _createSizemoveProbe() {
    if (kReleaseMode || !Platform.isWindows) return null;
    return Win32SizemoveBridge(logger: _log);
  }

  /// 平台最大化事件（经 [_onNativeEvent] 或测试直接驱动）。
  void onWindowMaximize() {
    if (_disposed) return;
    _log.d('onWindowMaximize()');
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
    _updateOnUIThread(_modeCoordinator.onNativeMaximize);
  }

  /// 平台取消最大化事件。
  void onWindowUnmaximize() {
    if (_disposed) return;
    _log.d('onWindowUnmaximize()');
    if (_modeCoordinator.fullscreenIntent) return;
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
    _updateOnUIThread(_modeCoordinator.onNativeUnmaximize);
  }

  /// 平台尺寸变化事件（拖拽期间连续触发）。
  void onWindowResize() {
    if (_disposed) return;
    if (_activeResizeSuppression != 0) {
      _activeResizeSuppression = 0;
      return;
    }
    _ensureResizeCoordinator();
    _resizeCoordinator?.onResize();
  }

  /// 平台关闭请求（默认关闭已被宿主取消）。
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
    await _runCloseCommand('hide', _host.hide);
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
      _runCloseCommand('destroy', _host.destroy).catchError((
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
    await _host.setAlwaysOnTop(value);
    if (_disposed) return;
    _state.isAlwaysOnTop.value = value;
    await _saveWindowState();
  }

  @override
  Future<void> minimize() async {
    if (_disposed) return;
    await _host.minimize();
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
    // 标题栏拖动走 nativeapi startDragging（Windows: 系统 HTCAPTION 拖动
    // 循环，保留 Aero Snap）。
    if (_disposed) return;
    await _host.startDragging();
  }

  @override
  bool setTitleBarDragRegion(Rect? logicalRect, double devicePixelRatio) {
    if (_disposed || !_hostAttached) return false;
    // 逻辑 → 物理：Flutter 视图铺满 runner 客户区，原点重合。
    final physical = logicalRect == null
        ? null
        : Rect.fromLTRB(
            logicalRect.left * devicePixelRatio,
            logicalRect.top * devicePixelRatio,
            logicalRect.right * devicePixelRatio,
            logicalRect.bottom * devicePixelRatio,
          );
    return _host.setTitleBarDragRegion(physical);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // 先使 resize coordinator 的延迟回调失效，再释放状态 notifier。
    _resizeCoordinator?.dispose();
    _state.dispose();
    _host.detach();
    _hostAttached = false;
  }
}
