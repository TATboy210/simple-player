import 'dart:async';
import 'dart:io' show Platform, exit;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';
import '../persistence/window_persistence.dart';
import 'native_window.dart';
import 'nativeapi_window.dart';
import 'normal_bounds_tracker.dart';
import 'window_bridge.dart';
import 'window_geometry.dart';

export 'window_bridge.dart';

final _log = KernelLogger.I;

/// Windows 11 起始内部版本号 — 低于此值的 Windows 10 走无 DWM frame 模式。
const int _windows11Build = 22000;

/// 命令落定等待上限 — 最大化/最小化由系统异步投递，等对应事件到达；
/// 上限只防事件丢失时卡住调用方。
const Duration _settleTimeout = Duration(milliseconds: 1000);

/// resize 会话防抖 — 最后一个 resize 事件后静默这么久才算会话结束。
const Duration _resizeDebounce = Duration(milliseconds: 500);

/// 关窗路径单步超时 — 卡住的步骤记日志后继续推进。
const Duration _closeStepTimeout = Duration(milliseconds: 800);

/// 窗口服务 — 单类封装 [NativeWindow]（生产为 nativeapi）。
///
/// 行为契约：
/// * 生命周期：[init] 隐藏态恢复几何 → 首帧栅格化后 [reveal] 亮窗；reveal 前
///   吞掉一切 resize 事件（恢复引发的 resize 不产生假会话/假落盘）。
/// * resize：500ms 防抖，[isResizing] 仅在会话边沿通知；全屏过渡的 resize
///   清标志但不落盘（防把显示器尺寸写进偏好，下次启动恢复成巨窗）。
/// * 模式：全屏意图标志让全屏期间的原生 maximize 事件映射回 fullscreen；
///   退出全屏回查宿主实际最大化状态。
/// * 落盘：存「最近一次普通窗口矩形」+ 最大化标志，最大化不覆盖还原尺寸；
///   恢复位置不在任何显示器工作区内时回落居中。
/// * 关窗（hide-first）：hide → persist → closing listeners → exit(0)，
///   每步 800ms 超时兜底，多路触发共享同一次执行。
class WindowService implements WindowBridge {
  /// 创建窗口服务。[bindWindow]/[exitOnClose]/[dropDwmFrame] 为测试 seam：
  /// 生产分别绑定 [NativeapiWindow.bind]、dart:io exit、Win10 版本探测。
  WindowService({
    WindowPersistence? persistence,
    NativeWindow Function()? bindWindow,
    void Function(int code)? exitOnClose,
    bool? dropDwmFrame,
  }) : _persistence = persistence ?? WindowPersistence(),
       _bindWindow = bindWindow ?? NativeapiWindow.bind,
       _exitOnClose = exitOnClose ?? exit,
       _dropDwmFrame = dropDwmFrame ?? _isWindows10();

  final WindowPersistence _persistence;
  final NativeWindow Function() _bindWindow;
  final void Function(int code) _exitOnClose;
  final bool _dropDwmFrame;

  NativeWindow? _native;
  StreamSubscription<NativeWindowEvent>? _eventSub;
  bool _revealed = false;
  bool _fullscreenIntent = false;
  bool _disposed = false;

  /// 最近一次普通窗口矩形的跟踪器 — 落盘的唯一几何来源。
  /// late final：初始化器需捕获 this（读 _native/_revealed/mode），惰性求值，
  /// 首次使用必在构造完成之后。
  late final NormalBoundsTracker _bounds = NormalBoundsTracker(
    window: () => _native,
    canTrack: () => _revealed && !mode.value.isFullscreen,
  );

  @override
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  @override
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  @override
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  @override
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  Timer? _resizeTimer;
  int _resizeGeneration = 0;

  /// 几何落盘串行队列 — 防并发整文件重写交错。
  Future<void> _saveQueue = Future<void>.value();

  final List<Future<void> Function()> _closingListeners = [];
  Future<void>? _closeOperation;
  Future<void>? _initOperation;

  NativeWindow get _bound {
    final window = _native;
    if (window == null) {
      throw StateError('WindowService used before init()');
    }
    return window;
  }

  // --- 生命周期 — init (隐藏态几何恢复) → reveal (亮窗) ---

  /// 绑定窗口并在隐藏态恢复几何。失败可重试，组合根负责降级兜底。
  Future<void> init() {
    if (_disposed) return Future<void>.value();
    return _initOperation ??= _initOnce().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _initOperation = null;
      _log.e('[WindowService.init] $error\n$stackTrace');
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _initOnce() async {
    final window = _native ??= _bindWindow();
    // Win10 去 DWM frame 防主题色顶线；先于 hideTitleBar，让原生只重算一次 frame。
    if (_dropDwmFrame) window.hasShadow = false;
    window.hideTitleBar();
    window.minimumSize = minimumWindowSize;
    _eventSub ??= window.events.listen(_onEvent);
    _log.i('[WindowService] event listener attached');

    final persisted = await _persistence.load();
    if (_disposed) return;
    _restoreGeometry(window, persisted);
    window.isAlwaysOnTop = persisted.alwaysOnTop;
    if (persisted.isMaximized) {
      // 隐藏态 maximize 只记「显示即最大化」标记，不会提前亮窗；runner 首帧
      // Show 直接以最大化形态出现，无普通→最大化闪变。
      await _settle(window.maximize, _isMaximizedSignal, () {
        return window.isMaximized;
      });
      if (_disposed) return;
    }
    isAlwaysOnTop.value = persisted.alwaysOnTop;
    mode.value = persisted.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }

  /// 恢复持久化几何。位置缺失、或不在任何显示器工作区内（上次的副屏已拔掉）
  /// 时只应用尺寸并居中，避免窗口出现在屏幕外找不回。
  void _restoreGeometry(NativeWindow window, PersistedWindowState persisted) {
    final rect = restoreBounds(
      position: persisted.position,
      size: persisted.size,
      workAreas: _workAreasOrEmpty(window),
    );
    if (rect != null) {
      window.bounds = rect;
      _bounds.value = rect;
      return;
    }
    if (persisted.position != null) {
      _log.w('[WindowService] persisted position off-screen — centering');
    }
    window.setSize(persisted.size);
    window.center();
    _bounds.value = window.bounds;
  }

  /// 工作区查询失败视为「未知」— [isReachableOnAnyDisplay] 对空列表信任原值。
  List<Rect> _workAreasOrEmpty(NativeWindow window) {
    try {
      return window.workAreas;
    } on Exception catch (error, stackTrace) {
      _log.w('[WindowService] work area query failed: $error\n$stackTrace');
      return const <Rect>[];
    }
  }

  static bool _isWindows10() {
    if (!Platform.isWindows) return false;
    // operatingSystemVersion 形如 '"Windows 10 Pro" 10.0 (Build 19045)'。
    final match = RegExp(r'Build (\d+)')
        .firstMatch(Platform.operatingSystemVersion);
    final build = int.tryParse(match?.group(1) ?? '');
    return build != null && build < _windows11Build;
  }

  /// 亮窗 — 首帧栅格化后由组合根调用（v0.0.4 空白窗口修复）。
  /// show + 条件 maximize + focus；同时解除 init 阶段的 resize 抑制。
  Future<void> reveal() async {
    if (_disposed) return;
    _revealed = true;
    final window = _bound..show();
    if (mode.value.isMaximized) {
      await _settle(window.maximize, _isMaximizedSignal, () {
        return window.isMaximized;
      });
      if (_disposed) return;
    }
    window.focus();
  }

  /// 降级亮窗 — init/reveal 失败时组合根 best-effort 调用。
  /// 宿主未绑定时无窗口可操作；runner 首帧回调仍会以系统默认形态亮窗。
  Future<void> showDegraded() async {
    _native?.show();
  }

  // --- 事件分发 ---

  void _onEvent(NativeWindowEvent event) {
    if (_disposed) return;
    switch (event) {
      case NativeMaximized():
        // 全屏意图期/全屏中的原生 maximize 是铺满的副产品 — 映射回 fullscreen，
        // 不降级为 maximized（单一数据源语义，防全屏 UI 误退）。
        mode.value = (_fullscreenIntent || mode.value.isFullscreen)
            ? WindowMode.fullscreen
            : WindowMode.maximized;
      case NativeRestored():
        _onNativeRestored();
      case NativeResized():
        _bounds.noteChanged();
        _onNativeResized();
      case NativeMoved():
        _bounds.noteChanged();
      case NativeCloseRequested(:final cancel):
        _onCloseRequested(cancel);
      case NativeMinimized():
        break;
    }
  }

  void _onNativeRestored() {
    if (_fullscreenIntent || mode.value.isFullscreen) return;
    // 最大化窗口最小化后恢复也只报 restored — 以宿主实际状态为准，
    // 避免把仍最大化的窗口误记为 windowed。
    mode.value = _bound.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }

  void _onNativeResized() {
    if (!_revealed) return;
    _resizeTimer?.cancel();
    final generation = ++_resizeGeneration;
    if (!isResizing.value) resizeSessionId.value++;
    isResizing.value = true;
    _resizeTimer = Timer(_resizeDebounce, () => _onResizeSettled(generation));
  }

  /// 视图尺寸实际变化（引擎指标，来自 [WindowMetricsObserver]）— 拖拽会话的
  /// **默认检测源**（阶段一改：取代 nativeapi 逐步事件流，见 nativeapi_window
  /// 的开关注释）。didChangeMetrics 由引擎按帧合并，频率远低于
  /// WM_WINDOWPOSCHANGED 洪泛，且不占窗口线程。会话防抖逻辑与旧事件源共用，
  /// 回退开关（SIMPLER_PLAYER_WINDOW_EVENTS=1）下两路并存亦幂等。
  void noteGeometryChanged() {
    if (_disposed || !_revealed) return;
    // 尺寸变化顺带校准一次模式（外部最大化/还原不再依赖事件）。
    _syncModeFromNative();
    _onNativeResized();
  }

  /// 现查宿主 `isMaximized` 校准 [mode]（一次轻量 FFI）。全屏意图/全屏中跳过
  /// — 全屏的原生形态不是最大化，查到 windowed 也会把 fullscreen 冲掉。
  void _syncModeFromNative() {
    final window = _native;
    if (window == null || !_revealed) return;
    if (_fullscreenIntent || mode.value.isFullscreen) return;
    mode.value = window.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }

  void _onResizeSettled(int generation) {
    if (_disposed || generation != _resizeGeneration) return;
    isResizing.value = false;
    // 会话结束再校准一次：覆盖"拖拽中途 isMaximized 翻转但无新指标"的边角。
    _syncModeFromNative();
    // 全屏进入/退出触发的 resize 是过渡而非用户意图 — 不落盘。
    if (!mode.value.isFullscreen) _schedulePersist();
  }

  // --- 模式切换 / 置顶 / 最小化 / 拖动 ---

  @override
  Future<void> setMode(WindowMode target) async {
    final window = _native;
    if (_disposed || window == null) return;
    final wasFullscreen = mode.value.isFullscreen;
    if (target.isFullscreen) {
      if (wasFullscreen) return;
      // 先提交意图+模式（全屏期间原生 maximize 映射回 fullscreen），再执行
      // 原生全屏。全屏属性经窗口线程同步执行，返回即落定。
      _fullscreenIntent = true;
      mode.value = WindowMode.fullscreen;
      window.isFullScreen = true;
      return;
    }
    _fullscreenIntent = false;
    if (mode.value == target) return;
    mode.value = target;
    if (wasFullscreen) {
      // 退出全屏原生已还原进入前几何（含最大化）；目标 windowed 但宿主实际
      // 是最大化时落回 maximized。
      window.isFullScreen = false;
      if (target.isWindowed && window.isMaximized) {
        mode.value = WindowMode.maximized;
      }
      return;
    }
    if (target.isMaximized) {
      await _settle(window.maximize, _isMaximizedSignal, () {
        return window.isMaximized;
      });
    } else {
      await _settle(
        window.unmaximize,
        (event) => event is NativeRestored,
        () => !window.isMaximized,
      );
    }
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    final window = _native;
    if (_disposed || window == null || value == isAlwaysOnTop.value) return;
    window.isAlwaysOnTop = value;
    isAlwaysOnTop.value = value;
    _schedulePersist();
  }

  @override
  Future<void> minimize() async {
    final window = _native;
    if (_disposed || window == null) return;
    await _settle(
      window.minimize,
      (event) => event is NativeMinimized,
      () => window.isMinimized,
    );
  }

  @override
  Future<void> startDragging() async {
    // 降级模式（init 失败）下窗口未绑定 — 手势回调静默无效，不抛。
    if (!_disposed) _native?.startDragging();
  }

  @override
  void titleBarDoubleClick() {
    if (!_disposed) _native?.performTitleBarDoubleClick();
  }

  static bool _isMaximizedSignal(NativeWindowEvent event) =>
      event is NativeMaximized;

  /// 执行 [command] 并等到 [signal] 事件到达（[isDone] 为真则立即返回）。
  ///
  /// maximize/minimize/unmaximize 在非窗口线程只投递 ShowWindow，返回时状态
  /// 可能尚未翻转。先订阅再下命令，避免错过事件；超时只记 warn 不阻塞调用方。
  Future<void> _settle(
    void Function() command,
    bool Function(NativeWindowEvent event) signal,
    bool Function() isDone,
  ) async {
    if (_disposed || isDone()) return;
    final settled = Completer<void>();
    void finish() {
      if (!settled.isCompleted) settled.complete();
    }

    // 事件流关闭（dispose）时也放行，避免白等满超时并在 dispose 后误报 warn。
    final subscription = _bound.events.listen((event) {
      if (signal(event)) finish();
    }, onDone: finish);
    try {
      command();
      if (isDone()) return;
      await settled.future.timeout(_settleTimeout);
    } on TimeoutException {
      _log.w(
        '[WindowService] window state did not settle within '
        '${_settleTimeout.inMilliseconds}ms — continuing',
      );
    } finally {
      // 同步广播流的 cancel 无需等待。
      unawaited(subscription.cancel());
    }
  }

  // --- 关窗时序（hide-first） ---

  @override
  Future<void> close() async {
    if (_disposed) return;
    await _beginClose();
  }

  /// 关窗时序的唯一入口 — 重复触发（✕ 连点 / 外部 WM_CLOSE）共享同一次执行。
  Future<void> _beginClose() => _closeOperation ??= _closeSequence();

  /// 平台关闭请求（✕ / Alt+F4 / WM_CLOSE）。
  void _onCloseRequested(bool Function() cancel) {
    // 取消默认 DestroyWindow — 服务完成持久化后 exit 收尾。
    if (!cancel()) {
      _log.d(
        '[WindowService] forced close (WM_CLOSE): not cancelable; '
        'runner re-posts SC_CLOSE for the cancelable path',
      );
    }
    unawaited(_beginClose());
  }

  /// 关窗时序：1) hide-first 窗口先视觉消失；2) 几何落盘；3) 应用级退出落盘
  /// （播放列表断点等）；4) exit(0) 立即终止进程 — 窗口已不可见、状态已落盘，
  /// 硬杀跳过引擎/libmpv 收尾等待（「窗口已消失但进程滞留」的根源），
  /// 播放器无跨进程状态。窗口由 OS 随进程退出销毁。
  Future<void> _closeSequence() async {
    _resizeTimer?.cancel();
    try {
      await _runCloseStep('hide', () => _native?.hide());
      // 先等排队中的落盘，避免与关窗落盘交错写同一份快照。
      await _runCloseStep('persist', () async {
        await _saveQueue;
        await _persistNow();
      });
      for (final listener in List.of(_closingListeners)) {
        await _runCloseStep('closing-listener', listener);
      }
    } finally {
      dispose();
      _exitOnClose(0);
    }
  }

  /// 执行关窗路径中的单个命令，附带超时兜底 — 超时不会取消底层调用，只是
  /// 不再等待。[step] 可为同步 void（FFI）或异步 Future。
  Future<void> _runCloseStep(
    String label,
    FutureOr<void> Function() step,
  ) async {
    try {
      await Future<void>.value(step()).timeout(_closeStepTimeout);
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
    // 移除函数幂等 — remove 对不存在元素是 no-op，重复调用安全。
    return () => _closingListeners.remove(listener);
  }

  // --- 持久化 ---

  /// 当前排队中的落盘 — 测试等待落盘完成用，避免依赖真实延时。
  @visibleForTesting
  Future<void> get pendingPersist => _saveQueue;

  /// 关窗序列的执行体 — 测试等待关窗完成用。
  @visibleForTesting
  Future<void>? get closeOperation => _closeOperation;

  /// 排队一次几何落盘 — 串行防交错；全屏时 [_persistNow] 内部跳过。
  void _schedulePersist() {
    _saveQueue = _saveQueue.then((_) => _persistNow());
    unawaited(_saveQueue);
  }

  Future<void> _persistNow() async {
    if (_disposed || mode.value.isFullscreen) return;
    // 普通窗口态下以现值为准（拖动结束可能没有 resize 事件），其余态沿用
    // 最近一次普通矩形，最大化因此不会覆盖还原尺寸。
    if (mode.value.isWindowed) _bounds.sample();
    final normal = _bounds.value;
    try {
      await _persistence.save(
        PersistedWindowState(
          size: Size(
            math.max(normal.width, minimumWindowSize.width),
            math.max(normal.height, minimumWindowSize.height),
          ),
          position: normal.topLeft,
          alwaysOnTop: isAlwaysOnTop.value,
          isMaximized: mode.value.isMaximized,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.w('[WindowService.persist] $error\n$stackTrace');
    }
  }

  // --- 释放 ---

  /// 释放窗口资源；重复调用安全。关窗序列末尾自动调用。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _bounds.dispose();
    unawaited(_eventSub?.cancel());
    _eventSub = null;
    _native?.dispose();
    mode.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
