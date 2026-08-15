import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import '../diagnostics/kernel_logger.dart';
import '../diagnostics/resize_frame_metrics.dart';
import '../persistence/window_persistence.dart';

/// 窗口模式枚举 — 替代散装 bool (isFullscreen/isMaximized)。
///
/// - `windowed`: Normal resizable window.
/// - `maximized`: OS-level maximized state.
/// - `fullscreen`: Borderless full-screen (covers taskbar).
enum WindowMode {
  /// 普通窗口。
  windowed,

  /// 最大化。
  maximized,

  /// 无边框全屏。
  fullscreen;

  bool get isWindowed => this == WindowMode.windowed;
  bool get isMaximized => this == WindowMode.maximized;
  bool get isFullscreen => this == WindowMode.fullscreen;
}

/// 窗口管理抽象接口 — UI 层依赖此接口，不依赖具体实现
///
/// 实现方：[WindowService]（Win32 真实实现）、FakeWindowService（测试替身）。
///
/// Contract:
/// - State is exposed through notifier getters so widgets can use
///   `ValueListenableBuilder` without depending on the platform implementation.
/// - Commands return `Future<void>`; implementations may serialize platform
///   operations when native completion order could otherwise reorder state.
/// - The composition root owns the bridge lifecycle and calls [dispose] once
///   after all consumers have stopped listening.
abstract class WindowBridge {
  // ─── 5 个 notifier 状态 + 1 个派生状态 ───

  /// 当前窗口模式（普通/最大化/全屏等）
  ///
  /// Contract: never null; changes notify all attached `ValueListenableBuilder` listeners.
  ValueNotifier<WindowMode> get mode;

  /// 当前窗口尺寸（像素）
  ///
  /// Contract: updated after resize completes; during drag-resize see [isResizing].
  ValueNotifier<Size> get windowSize;

  /// 窗口是否正在被用户拖拽调整大小
  ///
  /// Contract: `true` between drag-start and drag-end; useful for suppressing layout thrashing.
  ValueNotifier<bool> get isResizing;

  /// 当前连续 resize 会话的单调标识；0 表示尚未发生用户 resize。
  ///
  /// Contract: read-only diagnostic correlation source; it must not drive UI layout.
  ValueListenable<int> get resizeSessionId;

  /// 窗口是否置顶
  ///
  /// Contract: toggled via [setAlwaysOnTop]; implementations may persist the
  /// choice across application restarts.
  ValueNotifier<bool> get isAlwaysOnTop;

  /// 当前是否全屏 — 从 [mode] 派生，单一数据源
  ///
  /// Contract: read-only convenience; `true` iff `mode.value == WindowMode.fullscreen`.
  bool get isFullscreen;

  // ─── 7 个命令 ───

  /// 初始化窗口（应用固定默认状态并注册平台回调）
  ///
  /// Contract: completes only after the platform window has restored its persisted
  /// state and finished showing/focusing; concurrent calls share one operation.
  Future<void> init();

  /// 切换窗口模式（普通/最大化/全屏等）。
  ///
  /// Contract: [target] updates [mode] and therefore [isFullscreen]. Window
  /// geometry is updated only when the platform reports a settled resize.
  Future<void> setMode(WindowMode target);

  /// 设置窗口置顶状态
  ///
  /// Contract: [value] applies immediately and notifies [isAlwaysOnTop] listeners;
  /// implementations may persist it across application restarts.
  Future<void> setAlwaysOnTop(bool value);

  /// 最小化窗口
  ///
  /// Contract: platform-level minimize; does not change [mode] notifier.
  Future<void> minimize();

  /// 关闭窗口
  ///
  /// Contract: triggers platform close sequence; after completion the bridge is unusable.
  Future<void> close();

  /// 启动窗口拖拽移动（标题栏拖拽）
  ///
  /// Contract: delegates to platform drag; no-op if platform does not support programmatic drag.
  Future<void> startDragging();

  /// 释放所有资源（取消回调、清理状态）。
  ///
  /// Contract: the call is idempotent. Commands must not be issued after
  /// disposal; the bridge ignores late platform callbacks safely.
  void dispose();
}

/// Legacy compatibility shim.
///
/// The active window lifecycle now lives in [WindowService]; this file exists only
/// for older imports and tests that still reference [WindowState].
@Deprecated(
  'WindowService owns the active state. Prefer using the service directly.',
)
final class WindowState {
  WindowState({Size initialSize = const Size(1280, 752)})
    : _windowSize = ValueNotifier(initialSize);

  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  final ValueNotifier<Size> _windowSize;
  ValueNotifier<Size> get windowSize => _windowSize;

  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  bool _disposed = false;
  bool get disposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    _windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
  }
}

/// 日志门面 — WindowService 共用。
final logBridge = KernelLogger.I;

/// 真实窗口状态的唯一数据源；legacy [WindowState] 仅保留兼容入口。
///
/// This keeps the native window_manager logic in one class, while the old state
/// file is reduced to a compatibility shim instead of a second mutable source of
/// truth.
final class _WindowState {
  _WindowState({Size initialSize = const Size(1280, 752)})
    : _windowSize = ValueNotifier(initialSize);

  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  final ValueNotifier<Size> _windowSize;
  ValueNotifier<Size> get windowSize => _windowSize;

  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  bool _disposed = false;
  bool get disposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    _windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
  }
}

/// Window management service - thin coordinator combining responsibility components.
class WindowService with WindowListener implements WindowBridge {
  /// 创建 WindowService。
  ///
  /// 创建窗口服务。
  WindowService({WindowPersistence? persistence})
    : _persistence = persistence ?? WindowPersistence();

  final WindowPersistence _persistence;
  final _WindowState _state = _WindowState();
  // nullable: 构造时无法引用 _state (Dart 初始化列表禁实例成员),
  // 改在 init() 创建. dispose 用 ?., init 未调即 dispose 时安全跳过.
  ResizeFrameMetrics? _resizeMetrics;

  bool _disposed = false;
  bool _isClosing = false;
  bool _initialized = false;
  Future<void>? _initOperation;
  bool _isProgrammaticResize = false;
  Future<void> _modeOperation = Future<void>.value();
  int _modeGeneration = 0;
  Future<void> _saveOperation = Future<void>.value();
  bool _skipNextResize = false;

  /// 全屏意图标记 — setMode(fullscreen) 置 true, setMode(windowed 从 fullscreen) 置 false.
  /// 系统全屏铺满走 SC_MAXIMIZE(最大化), 会触发 onWindowMaximize;
  /// 此标记守卫 onWindowMaximize/onWindowUnmaximize, 防止 mode 被覆盖成 maximized.
  bool _fullscreenIntent = false;

  /// resize 防抖延迟 — 500ms 内无新 resize 事件才更新 windowSize。
  static const int _resizeDebounceMs = 500;

  Timer? _resizeTimer;
  Future<void>? _closeOperation;

  /// 递增式会话标记，令已开始的旧 debounce 异步读取失效。
  ///
  /// 取消 Timer 无法中断已进入 `getSize()` 的 Future；完成后必须确认其
  /// 仍属于当前 resize 会话，才可写入窗口状态或关闭降级渲染模式。
  int _resizeGeneration = 0;

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
  ValueListenable<int> get resizeSessionId => _state.resizeSessionId;
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
      logBridge.e('[WindowService.init] $error\n$stackTrace');
      throw error;
    });
  }

  Future<void> _initOnce() async {
    var listenerAdded = false;
    try {
      await windowManager.ensureInitialized();
      // 拦截原生关闭事件，确保异步窗口状态持久化完成后再销毁窗口。
      await windowManager.setPreventClose(true);
      const options = WindowOptions(
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        minimumSize: Size(854, 513),
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
      // 构造时无法引用 _state (Dart 初始化列表禁实例成员), 故延后到 init.
      // 此时 binding 已就绪, isResizing 监听器开始接管后续 resize 会话切片.
      _resizeMetrics = ResizeFrameMetrics(
        isResizing: _state.isResizing,
        resizeSessionId: _state.resizeSessionId,
      );
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
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _resizeMetrics?.dispose();
    _resizeMetrics = null;
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
      logBridge.e('[WindowService._initWindow] $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> _initWindow() async {
    // 保持 hidden title bar 配置，不再切换 frameless 样式；Windows runner
    // 通过 WM_NCHITTEST 返回原生 HT* 命中结果，继续交给系统 resize loop。
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
    _skipNextResize = true;
    await windowManager.show();
    if (_disposed) return;
    if (persisted.isMaximized) {
      await windowManager.maximize();
      if (_disposed) return;
    }
    await windowManager.focus();
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
    } on Exception catch (error, stackTrace) {
      // 调度器不可用时保留同步更新，并记录异常上下文便于诊断。
      logBridge.w('[WindowService._updateOnUIThread] $error\n$stackTrace');
      update();
    } on Error {
      // 清理/测试阶段可能抛出 Error；保持原有兜底行为但继续传播不可恢复错误。
      update();
      rethrow;
    }
  }

  /// 单一 resize 定时器 — 合并 isResizing 标记和 windowSize 更新。
  void _startResizeTimer() {
    _resizeTimer?.cancel();
    // 新事件使已在 await getSize() 的旧 debounce 结果过期，避免它提前
    // 结束当前会话并恢复 blur/filter quality 等高成本渲染路径。
    final generation = ++_resizeGeneration;
    // 红线放宽: isResizing=true 同步翻转, 不走 _updateOnUIThread 推迟.
    // 原推迟致会话起手 1-2 帧 isResizing 仍 false → ExcludeSemantics/
    // BackdropFilter 未及时生效 → 边沿尖峰 (实测 build max 58ms, avg 2-3ms).
    // 同步安全: 消费者全是 VLB(setState→markNeedsBuild 仅标记 dirty, 不同步
    // layout) + 诊断器(无 layout) + AutoHideController(Timer) → 无重入断言.
    // 边界: 仅放宽 isResizing=true; windowSize(防抖 500ms)/isResizing=false/
    // mode 翻转仍走 _updateOnUIThread (重操作推迟仍合理, 不动).
    // listener 同步通知；先分配新会话 ID，保证 diagnostics 在收到 true 时
    // 立即关联到正确会话。活跃会话中的事件只续期 debounce/generation。
    if (!_state.isResizing.value) {
      _state.resizeSessionId.value++;
    }
    _state.isResizing.value = true;
    // Timer callback 期望同步; .then 链改 await 需 async 宿主,
    // 提取 _onResizeDebounce() (DCM prefer-async-await).
    _resizeTimer = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () => unawaited(_onResizeDebounce(generation)),
    );
  }

  /// resize 防抖结束处理 — 落定窗口尺寸 + isResizing=false。
  ///
  /// [generation] 防止无法取消的旧 `getSize()` 异步完成覆盖新拖拽会话。
  Future<void> _onResizeDebounce(int generation) async {
    if (!_isCurrentResizeGeneration(generation)) return;

    Size? size;
    try {
      size = await windowManager.getSize();
    } on Exception catch (error, stackTrace) {
      // 平台查询失败也必须结束当前会话，否则控件和渲染降级会永久滞留。
      logBridge.e('[WindowService._onResizeDebounce] $error\n$stackTrace');
    }

    if (!_isCurrentResizeGeneration(generation)) return;
    _updateOnUIThread(() {
      // post-frame 前可能已有新 resize；旧 callback 不得关闭新会话。
      if (!_isCurrentResizeGeneration(generation)) return;
      final settledSize = size;
      // 无论尺寸是否净变化,resize 已停止 — 必须落 isResizing=false.
      // 旧逻辑把 isResizing=false 包在 if(size!=windowSize) 内,致
      // "拖大又拖回原尺寸"等净变化为零场景 isResizing 卡 true,
      // 控制栏永不恢复、BackdropFilter 永久跳过 (方向2 状态边界 bug).
      if (settledSize != null && settledSize != _state.windowSize.value) {
        _state.windowSize.value = Size(
          math.max(settledSize.width, 854),
          math.max(settledSize.height, 513),
        );
      }
      _state.isResizing.value = false;
      // Persist after the UI state is settled so the next launch uses this size.
      unawaited(_saveWindowState(size: _state.windowSize.value));
    });
  }

  /// 判断异步 resize 结果是否仍可触碰当前窗口状态。
  bool _isCurrentResizeGeneration(int generation) =>
      !_disposed && generation == _resizeGeneration;

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    logBridge.d('onWindowMaximize() fullscreenIntent=$_fullscreenIntent');
    _startResizeTimer();
    _updateOnUIThread(() {
      if (_fullscreenIntent) {
        // 全屏切换的 SC_MAXIMIZE — 保持 fullscreen, 不被 maximized 覆盖.
        if (_state.mode.value != WindowMode.fullscreen) {
          _state.mode.value = WindowMode.fullscreen;
        }
      } else if (_state.mode.value != WindowMode.maximized) {
        _state.mode.value = WindowMode.maximized;
      }
    });
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    logBridge.d('onWindowUnmaximize() fullscreenIntent=$_fullscreenIntent');
    // 全屏期间忽略 unmaximize 噪音 (退出全屏的 SC_RESTORE 可能触发).
    // 退出全屏由 setMode(windowed) 显式设 mode, 不依赖此回调.
    if (_fullscreenIntent) return;
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
    if (_skipNextResize) {
      _skipNextResize = false;
      return;
    }
    if (_isProgrammaticResize) {
      _isProgrammaticResize = false;
      return;
    }
    _startResizeTimer();
  }

  @override
  void onWindowClose() {
    if (_disposed || _isClosing) return;
    logBridge.i('onWindowClose()');
    _isClosing = true;
    _resizeTimer?.cancel();
    ++_resizeGeneration;
    // Finish the preference write before destroying the native window.
    unawaited(_closeWindowOperation());
  }

  Future<void> _closeWindowOperation() {
    return _closeOperation ??= _persistThenDestroy();
  }

  Future<void> _persistThenDestroy() async {
    try {
      // 等待已发出的窗口命令完成，再读取最终置顶/模式状态。
      await _modeOperation;
      // 关闭可能发生在 resize 防抖完成前，优先读取 native 尺寸避免保存旧快照。
      Size? closingSize;
      try {
        closingSize = await windowManager.getSize();
      } on Exception catch (error, stackTrace) {
        logBridge.w('[WindowService._persistThenDestroy] $error\n$stackTrace');
      }
      await _saveWindowState(size: closingSize);
      await windowManager.destroy();
    } finally {
      dispose();
    }
  }

  /// Saves the current settled geometry without letting persistence failures affect UI.
  Future<void> _saveWindowState({Size? size}) {
    final operation = _saveOperation.then(
      (_) => _saveWindowStateSerialized(size: size),
    );
    _saveOperation = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      logBridge.w('[WindowService._saveWindowState] $error\n$stackTrace');
    });
    return operation;
  }

  Future<void> _saveWindowStateSerialized({Size? size}) async {
    if (_disposed || _state.mode.value.isFullscreen) return;
    try {
      final position = await windowManager.getPosition();
      if (_disposed) return;
      await _persistence.save(
        PersistedWindowState(
          size: size ?? _state.windowSize.value,
          position: position,
          alwaysOnTop: _state.isAlwaysOnTop.value,
          isMaximized: _state.mode.value == WindowMode.maximized,
        ),
      );
    } on Exception catch (error, stackTrace) {
      logBridge.w('[WindowService._saveWindowState] $error\n$stackTrace');
    }
  }

  @override
  Future<void> setMode(WindowMode target) {
    // 模式切换必须串行，避免快速切换时旧状态覆盖最新意图。
    final operation = _modeOperation.then((_) => _setModeSerialized(target));
    _modeOperation = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      logBridge.e('[WindowService.setMode] $error\n$stackTrace');
    });
    return operation;
  }

  Future<void> _setModeSerialized(WindowMode target) async {
    // 初始化恢复优先完成，避免用户命令被持久化快照覆盖。
    final initOperation = _initOperation;
    if (initOperation != null) await initOperation;
    if (_disposed || target == _state.mode.value) return;
    final operationGeneration = ++_modeGeneration;
    final previous = _state.mode.value;
    logBridge.i('setMode($target) <- $previous');

    switch (target) {
      case WindowMode.windowed:
        _fullscreenIntent = false;
        _commitModeIfCurrent(operationGeneration, WindowMode.windowed);
        if (previous == WindowMode.maximized) {
          await windowManager.unmaximize();
        }
      case WindowMode.maximized:
        _fullscreenIntent = false;
        _commitModeIfCurrent(operationGeneration, WindowMode.maximized);
        await windowManager.maximize();
      case WindowMode.fullscreen:
        // 实际全屏由 UI 层的 media_kit VideoState.toggleFullscreen 负责；
        // 此处只同步语义状态，不修改 HWND 的原生 resize 能力。
        _fullscreenIntent = true;
        _commitModeIfCurrent(operationGeneration, WindowMode.fullscreen);
    }
  }

  void _commitModeIfCurrent(int generation, WindowMode mode) {
    if (_disposed || generation != _modeGeneration) return;
    _state.mode.value = mode;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) {
    final operation = _modeOperation.then(
      (_) => _setAlwaysOnTopSerialized(value),
    );
    _modeOperation = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      logBridge.e('[WindowService.setAlwaysOnTop] $error\n$stackTrace');
    });
    return operation;
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
    _resizeTimer?.cancel();
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
    // _resizeMetrics 监听 _state.isResizing — 必须先于 _state.dispose(),
    // 否则 removeListener 触发 "used after being disposed". nullable: init
    // 未调时为 null (如纯单元测试), ? 安全跳过.
    _resizeMetrics?.dispose();
    _resizeTimer?.cancel();
    _state.dispose();
    windowManager.removeListener(this);
  }
}
