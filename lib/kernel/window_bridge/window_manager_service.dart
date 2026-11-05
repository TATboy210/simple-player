import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform, exit;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as na;

import '../bridge/win32/caption_region_bridge.dart';
import '../bridge/win32/runner_window_handle.dart';
import '../diagnostics/kernel_logger.dart';
import '../persistence/window_persistence.dart';
import 'window_bridge.dart';
import 'window_constants.dart';

export 'window_bridge.dart';

/// 日志门面 — WindowService 共用。
final _log = KernelLogger.I;

/// Windows 11 起始内部版本号 — 低于此值的 Windows 10 走无 DWM frame 模式。
const int _windows11Build = 22000;

/// 投递命令后的落定轮询间隔与次数 (上限 ~1s) — 命令在下一轮消息循环执行,
/// 上限只防命令丢失时卡住调用方。
const Duration _settlePollInterval = Duration(milliseconds: 8);
const int _settlePolls = 125;

/// 精简窗口服务 — 单类直接封装 nativeapi (2026-10-21 重建, 0.5.10 去补丁)。
///
/// 上一代 (端口 + 三协调器) 的全部行为契约在本类内联保留：
/// * resize 500ms 防抖 settle 后才更新 windowSize 并落盘; isResizing 仅在
///   会话转换沿通知; 全屏过渡 resize 清标志但不落盘 (防把显示器尺寸写进
///   偏好导致下次启动恢复成巨窗)。
/// * 模式语义: 全屏意图标志 (全屏期间原生 maximize 事件映射回 fullscreen、
///   不降级为 maximized)、退出全屏回查宿主实际最大化状态。
/// * 关窗时序 (hide-first): hide → persist → closing listeners → exit(0),
///   每步 800ms 超时兜底, 卡住的操作记日志后继续推进。退出即由 OS 销毁
///   窗口, 不再单独 destroy。
/// * 窗口状态命令直接调用 nativeapi: UI isolate 已不在 platform 线程
///   (nativeapi 0.5.3 起事件观察在窗口所属线程), 同步 FFI 不再挡住引擎
///   产帧。maximize/minimize/unmaximize 由系统异步投递, 8ms×125 轮询到
///   落定后返回; 落空记 warn。
/// * init 隐藏态几何恢复; [reveal] 之前吞掉一切 resize 事件 (恢复引发的
///   WM_SIZE 不产生假会话/假落盘)。
///
/// 测试: 构造器注入 [WindowPersistence] 与 [exitOnClose] seam。
class WindowService implements WindowBridge {
  /// 创建窗口服务。[exitOnClose] 注入 seam — 关窗终点的进程终止调用，
  /// 生产绑定 dart:io exit；测试注入 no-op 避免 test runner 被杀。
  WindowService({
    WindowPersistence? persistence,
    void Function(int code)? exitOnClose,
  }) : _persistence = persistence ?? WindowPersistence(),
       _exitOnClose = exitOnClose ?? exit;

  final WindowPersistence _persistence;
  final void Function(int code) _exitOnClose;

  na.Window? _window;

  /// Windows runner HWND（其他平台 0）— 关闭放行属性与拖动区写在其上。
  int _hwnd = 0;
  na.ListenerId? _listenerId;
  bool _isClosing = false;
  bool _revealed = false;
  bool _fullscreenIntent = false;
  bool _disposed = false;

  @override
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  @override
  final ValueNotifier<Size> windowSize = ValueNotifier(defaultWindowSize);
  @override
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  @override
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  @override
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  Timer? _resizeTimer;
  int _resizeGeneration = 0;

  /// 几何落盘串行队列 — 防并发整文件重写交错 (单 blob 写入天然原子,
  /// 串行只保证顺序)。
  Future<void> _saveQueue = Future<void>.value();

  final List<Future<void> Function()> _closingListeners = [];
  Future<void>? _closeOperation;
  Future<void>? _initOperation;

  static const _resizeDebounce = Duration(milliseconds: 500);
  static const _closeCommandTimeout = Duration(milliseconds: 800);

  @override
  bool get isFullscreen => mode.value.isFullscreen;

  na.Window get _bound {
    final window = _window;
    if (window == null) {
      throw StateError('WindowService used before init()');
    }
    return window;
  }

  // =========================================================================
  // 生命周期 — init (隐藏态几何恢复) → reveal (亮窗)
  // =========================================================================

  @override
  Future<void> init() {
    if (_disposed) return Future<void>.value();
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
    _bindWindow();
    final window = _bound;
    if (Platform.isWindows && _isWindows10()) {
      // Win10 去 DWM frame 防主题色顶线; 先于 hidden 设置, nativeapi 只做
      // 一次 frame 重算。
      window.hasShadow = false;
    }
    window.titleBarStyle = na.TitleBarStyle.hidden;
    window.minimumSize = na.Size(
      width: minimumWindowSize.width,
      height: minimumWindowSize.height,
    );
    _listenerId ??= window.addListener(_onEvent);
    _log.i('[WindowService] event listener attached');

    // 隐藏态几何恢复 — 只恢复已校验快照; 损坏偏好回落 720p (load 内部保证)。
    final persisted = await _persistence.load();
    if (_disposed) return;
    if (persisted.position case final position?) {
      window.bounds = na.Rectangle(
        x: position.dx,
        y: position.dy,
        width: persisted.size.width,
        height: persisted.size.height,
      );
    } else {
      // 首次启动或位置损坏时仍应用已校验的尺寸, 并交给平台居中。
      window.setSize(
        na.Size(width: persisted.size.width, height: persisted.size.height),
        false,
      );
      window.center();
    }
    window.isAlwaysOnTop = persisted.alwaysOnTop;
    if (persisted.isMaximized) {
      // 隐藏态 maximize: nativeapi 不立即 SW_MAXIMIZE (会提前亮窗), 而是
      // 标记「显示即最大化」— runner 首帧 Show 直接以最大化形态出现,
      // 无普通→最大化闪变。
      await _awaitSettled(window.maximize, () => window.isMaximized);
      if (_disposed) return;
    }
    windowSize.value = persisted.size;
    isAlwaysOnTop.value = persisted.alwaysOnTop;
    mode.value = persisted.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }

  /// nativeapi 绑定当前 runner 窗口 — Windows 隐藏态下 GetActiveWindow 为
  /// null, 自行定位 HWND (进程内枚举, 见 runner_window_handle.dart);
  /// macOS/Linux 走 WindowManager。
  void _bindWindow() {
    if (_window != null) return;
    if (Platform.isWindows) {
      final hwnd = findRunnerWindowHandle();
      if (hwnd == 0) {
        throw StateError('window: Flutter host window not found');
      }
      _hwnd = hwnd;
      _window = na.Window.createWithNativeWindow(
        ffi.Pointer<ffi.Void>.fromAddress(hwnd),
      );
      return;
    }
    _window =
        na.WindowManager.instance.getCurrent() ??
        na.WindowManager.instance.getAll().firstOrNull;
  }

  static bool _isWindows10() {
    // operatingSystemVersion 形如 '"Windows 10 Pro" 10.0 (Build 19045)'。
    final match = RegExp(r'Build (\d+)')
        .firstMatch(Platform.operatingSystemVersion);
    final build = int.tryParse(match?.group(1) ?? '');
    return build != null && build < _windows11Build;
  }

  /// 亮窗 — 首帧栅格化后由组合根调用 (v0.0.4 空白窗口修复)。
  ///
  /// show + 条件 maximize (init 恢复路径已同步持久化态) + focus; 同时解除
  /// init 阶段的 resize 抑制。
  Future<void> reveal() async {
    if (_disposed) return;
    _revealed = true;
    _bound.show();
    if (_disposed) return;
    if (mode.value.isMaximized) {
      await _awaitSettled(_bound.maximize, () => _bound.isMaximized);
      if (_disposed) return;
    }
    _bound.focus();
  }

  /// 降级亮窗 — init/reveal 失败时组合根 best-effort 调用。
  ///
  /// 宿主未绑定时无窗口可操作：runner 首帧回调仍会以系统默认形态显示窗口。
  Future<void> showDegraded() async {
    final window = _window;
    if (window == null) return;
    window.show();
  }

  // =========================================================================
  // 事件分发 — nativeapi 事件 → 内联语义 (无中间端口层)
  // =========================================================================

  void _onEvent(na.WindowEvent event) {
    switch (event) {
      case na.WindowMaximizedEvent():
        _onNativeMaximize();
      case na.WindowRestoredEvent():
        unawaited(_onNativeRestored());
      case na.WindowResizedEvent():
        _onNativeResized();
      case na.WindowCloseRequestedEvent(:final request):
        _onCloseRequested(request);
      default:
        // moved/focused/blurred 等 — 无应用语义 (焦点日志由需要方自取)。
        break;
    }
  }

  void _onNativeMaximize() {
    if (_disposed) return;
    // 全屏意图期/全屏中的原生 maximize 是铺满的副产品 — 映射回 fullscreen,
    // 不降级为 maximized (单一数据源语义, 防全屏 UI 误退)。
    mode.value = (_fullscreenIntent || mode.value == WindowMode.fullscreen)
        ? WindowMode.fullscreen
        : WindowMode.maximized;
  }

  Future<void> _onNativeRestored() async {
    if (_disposed) return;
    if (_fullscreenIntent || mode.value == WindowMode.fullscreen) return;
    try {
      // 最大化窗口最小化后恢复也只报 restored — 以宿主实际状态为准,
      // 避免把仍最大化的窗口误记为 windowed。
      mode.value = _bound.isMaximized
          ? WindowMode.maximized
          : WindowMode.windowed;
    } on Exception catch (error, stackTrace) {
      _log.w('[WindowService.onRestored] $error\n$stackTrace');
      mode.value = WindowMode.windowed;
    }
  }

  void _onNativeResized() {
    if (_disposed || !_revealed) return;
    _resizeTimer?.cancel();
    final generation = ++_resizeGeneration;
    if (!isResizing.value) resizeSessionId.value++;
    isResizing.value = true;
    _resizeTimer = Timer(
      _resizeDebounce,
      () => unawaited(_onResizeSettled(generation)),
    );
  }

  Future<void> _onResizeSettled(int generation) async {
    if (_disposed || generation != _resizeGeneration) return;
    // 全屏进入/退出触发的 resize 是过渡而非用户意图 — 清 isResizing
    // (filterQuality 恢复依赖它) 但不更新 windowSize、不落盘。
    if (mode.value.isFullscreen) {
      isResizing.value = false;
      return;
    }
    final raw = _bound.size;
    final size = Size(
      math.max(raw.width, minimumWindowSize.width),
      math.max(raw.height, minimumWindowSize.height),
    );
    if (size != windowSize.value) windowSize.value = size;
    isResizing.value = false;
    _schedulePersist();
  }

  // =========================================================================
  // 模式切换
  // =========================================================================

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed) return;
    switch (target) {
      case WindowMode.fullscreen:
        if (mode.value == WindowMode.fullscreen) return;
        // 先提交意图+模式 (全屏期间原生 maximize 映射回 fullscreen),
        // 再执行原生全屏。
        _fullscreenIntent = true;
        mode.value = WindowMode.fullscreen;
        await _awaitSettled(
          () => _bound.isFullScreen = true,
          () => _bound.isFullScreen,
        );
      case WindowMode.maximized:
        _fullscreenIntent = false;
        if (mode.value == WindowMode.maximized) return;
        if (mode.value == WindowMode.fullscreen) {
          // 退出全屏恢复进入前几何 (含最大化) — 原生已还原到位。
          mode.value = WindowMode.maximized;
          await _exitFullscreen();
          return;
        }
        mode.value = WindowMode.maximized;
        await _awaitSettled(_bound.maximize, () => _bound.isMaximized);
      case WindowMode.windowed:
        _fullscreenIntent = false;
        if (mode.value == WindowMode.windowed) return;
        if (mode.value == WindowMode.fullscreen) {
          mode.value = WindowMode.windowed;
          await _exitFullscreen();
          // 退出全屏落回进入前模式 — 原生恢复了进入前几何, 以实际状态为准。
          if (_bound.isMaximized) mode.value = WindowMode.maximized;
          return;
        }
        mode.value = WindowMode.windowed;
        await _awaitSettled(_bound.unmaximize, () => !_bound.isMaximized);
    }
  }

  Future<void> _exitFullscreen() async {
    _fullscreenIntent = false;
    await _awaitSettled(
      () => _bound.isFullScreen = false,
      () => !_bound.isFullScreen,
    );
  }

  /// 执行一次窗口状态命令并等到它落定。
  ///
  /// nativeapi 在非 owner 线程调用 `maximize`/`minimize`/`unmaximize` 时只
  /// 投递 `ShowWindow`, 返回时状态可能尚未翻转 — 这里轮询到 [settled] 为真
  /// 再返回, 让调用方读到落定状态。全屏 / titleBarStyle 走 nativeapi 的
  /// `OnWindowThread` 同步等待, 首轮即退出。轮询落空只记 warn, 不阻塞调用方。
  Future<void> _awaitSettled(
    void Function() direct,
    bool Function() settled,
  ) async {
    if (_window == null || _disposed) return;
    if (!settled()) direct();
    for (var i = 0; i < _settlePolls && !settled(); i++) {
      await Future<void>.delayed(_settlePollInterval);
    }
    if (!settled()) {
      _log.w(
        '[WindowService] window state did not settle within '
        '${_settlePolls * _settlePollInterval.inMilliseconds}ms — continuing',
      );
    }
  }

  // =========================================================================
  // 置顶 / 最小化 / 拖动 / 拖动区
  // =========================================================================

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (_disposed || value == isAlwaysOnTop.value) return;
    _bound.isAlwaysOnTop = value;
    isAlwaysOnTop.value = value;
    _schedulePersist();
  }

  @override
  Future<void> minimize() async {
    if (_disposed) return;
    await _awaitSettled(_bound.minimize, () => _bound.isMinimized);
  }

  @override
  Future<void> startDragging() async {
    if (_disposed) return;
    // 标题栏拖动走 nativeapi startDragging (Windows: 系统 HTCAPTION 拖动
    // 循环, 保留 Aero Snap) — 原生拖动区未接管时的手势兜底路径。
    _bound.startDragging();
  }

  @override
  bool setTitleBarDragRegion(Rect? logicalRect, double devicePixelRatio) {
    if (!Platform.isWindows || _hwnd == 0) return false;
    // 逻辑 → 物理: Flutter 视图铺满 runner 客户区, 原点重合。
    final physical = logicalRect == null
        ? null
        : Rect.fromLTRB(
            logicalRect.left * devicePixelRatio,
            logicalRect.top * devicePixelRatio,
            logicalRect.right * devicePixelRatio,
            logicalRect.bottom * devicePixelRatio,
          );
    return setRunnerCaptionRect(_hwnd, physical);
  }

  // =========================================================================
  // 关窗时序 (hide-first, 学自 BlueBubbles)
  // =========================================================================

  @override
  Future<void> close() async {
    if (_disposed) return;
    if (_isClosing) {
      await (_closeOperation ?? Future<void>.value());
      return;
    }
    _isClosing = true;
    _closeOperation = _closeSequence();
    await _closeOperation;
  }

  /// 平台关闭请求 (✕ / Alt+F4 / WM_CLOSE — 默认关闭已被取消)。
  void _onCloseRequested(na.EventRequest request) {
    // 取消默认 DestroyWindow — 服务完成持久化后 exit 收尾。
    if (!request.cancel()) {
      _log.d(
        '[WindowService] forced close (WM_CLOSE): not cancelable; '
        'runner re-posts SC_CLOSE for the cancelable path',
      );
    }
    if (_isClosing) return;
    _isClosing = true;
    _closeOperation = _closeSequence();
    unawaited(_closeOperation!);
  }

  /// 关窗时序: 1) hide-first 窗口先视觉消失; 2) 几何落盘; 3) 应用级退出
  /// 落盘 (播放列表断点等); 4) exit(0) 立即终止进程 — 窗口已不可见、状态
  /// 已落盘, 硬杀跳过引擎/libmpv 收尾等待 (「窗口已消失但进程滞留」的根源),
  /// 播放器无跨进程状态, 硬杀无副作用。窗口本身由 OS 随进程退出销毁, 不再
  /// 单独 destroy。测试注入 [_exitOnClose] seam 拦截。
  Future<void> _closeSequence() async {
    _resizeTimer?.cancel();
    await _runCloseStep('hide', _bound.hide);
    await _runCloseStep('persist', _persistNow);
    for (final listener in List.of(_closingListeners)) {
      await _runCloseStep('closing-listener', listener);
    }
    dispose();
    _exitOnClose(0);
  }

  /// 执行关窗路径中的单个命令, 附带超时兜底 — 超时不会取消底层调用,
  /// 只是不再等待, 卡住的命令记日志后放任自生自灭。[step] 可为同步 void
  /// (nativeapi FFI) 或异步 Future (SharedPreferences/listeners)。
  Future<void> _runCloseStep(
    String label,
    FutureOr<void> Function() step,
  ) async {
    try {
      await Future<void>.value(step()).timeout(_closeCommandTimeout);
    } on TimeoutException {
      _log.w('[WindowService.close] "$label" timed out — continuing anyway');
    } on Object catch (error, stackTrace) {
      // 关窗路径刻意容纳一切 — 绝不让清理失败阻断退出。
      _log.e('[WindowService.close] "$label" failed: $error\n$stackTrace');
    }
  }

  @override
  void Function() addClosingListener(Future<void> Function() listener) {
    _closingListeners.add(listener);
    // 移除函数幂等 — remove 对不存在元素是 no-op, 重复调用安全。
    return () => _closingListeners.remove(listener);
  }

  // =========================================================================
  // 持久化
  // =========================================================================

  /// 排队一次几何落盘 — 串行防交错; 全屏时 [persistNow] 内部跳过。
  void _schedulePersist() {
    _saveQueue = _saveQueue.then((_) => _persistNow());
    unawaited(_saveQueue);
  }

  Future<void> _persistNow() async {
    if (_disposed || mode.value.isFullscreen) return;
    try {
      final position = _bound.position;
      await _persistence.save(
        PersistedWindowState(
          size: windowSize.value,
          position: Offset(position.x, position.y),
          alwaysOnTop: isAlwaysOnTop.value,
          isMaximized: mode.value == WindowMode.maximized,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.w('[WindowService.persist] $error\n$stackTrace');
    }
  }

  // =========================================================================
  // 释放
  // =========================================================================

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    final id = _listenerId;
    if (id != null) _window?.removeListener(id);
    _listenerId = null;
    mode.dispose();
    windowSize.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
