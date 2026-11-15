import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart';

import '../../diagnostics/kernel_logger.dart';
import '../../persistence/window_persistence.dart';
import '../platform/close_notifier_bridge.dart';
import '../platform/platform_profile.dart';
import '../port/native_window.dart';
import '../port/nativeapi_window.dart';
import '../port/window_resize_edge.dart';
import '../window_bridge.dart';
import 'close_sequence.dart';
import 'geometry_restore.dart';
import 'mode_controller.dart';
import 'normal_bounds_tracker.dart';
import 'persist_queue.dart';
import 'resize_session.dart';
import 'window_geometry.dart';

export '../window_bridge.dart';

/// 窗口服务 — 门面组合根，行为规格见 ../CONTRACT.md（十条契约）。
///
/// 事件模型（契约 1/2）：不订阅 nativeapi 逐步事件流（三平台共有的拖拽
/// 卡顿根因，取证 docs/audit/resize-drag-ab-2026-11.md）；几何变化检测源 =
/// 引擎指标（[WindowMetricsObserver] → [noteGeometryChanged]），模式靠现查
/// `isMaximized` 校准，关门走 runner 专线（[CloseNotifierBridge]）。
///
/// 本类只做组装与生命周期，行为细节委托协作者：
/// [ResizeSession]（契约 3）、[ModeController]（契约 4）、[GeometryRestore]
/// （契约 5/10）、[PersistQueue]（契约 8）、[CloseSequence]（契约 7）、
/// [NormalBoundsTracker]（契约 9）。
class WindowService implements WindowBridge {
  /// 创建窗口服务。[bindWindow]/[exitOnClose]/[installCloseNotifier] 为测试
  /// seam：生产分别绑定 [NativeapiWindow.bind]、dart:io exit、
  /// [CloseNotifierBridge.install]。[profile] 缺省生产探测；[dropDwmFrame]
  /// 为向后兼容 seam，显式传入时覆盖 profile 的同名判定。
  WindowService({
    WindowPersistence? persistence,
    NativeWindow Function()? bindWindow,
    void Function(int code)? exitOnClose,
    bool? dropDwmFrame,
    WindowPlatformProfile? profile,
    bool Function(void Function() onHostClose)? installCloseNotifier,
  }) : _persistence = persistence ?? WindowPersistence(),
       _installCloseNotifier =
           installCloseNotifier ?? CloseNotifierBridge.install,
       _bindWindow = bindWindow ?? NativeapiWindow.bind,
       _exitOnClose = exitOnClose ?? exit,
       _profile = _resolveProfile(profile, dropDwmFrame);

  /// seam 合并：显式 dropDwmFrame 覆盖探测值，其余沿用 profile。
  static WindowPlatformProfile _resolveProfile(
    WindowPlatformProfile? profile,
    bool? dropDwmFrame,
  ) {
    final base = profile ?? WindowPlatformProfile.detect();
    if (dropDwmFrame == null) return base;
    return WindowPlatformProfile(
      dropDwmFrame: dropDwmFrame,
      supportsWindowPositioning: base.supportsWindowPositioning,
      needsResizeHotZones: base.needsResizeHotZones,
    );
  }

  final WindowPersistence _persistence;
  final NativeWindow Function() _bindWindow;
  final void Function(int code) _exitOnClose;
  final WindowPlatformProfile _profile;
  final bool Function(void Function() onHostClose) _installCloseNotifier;

  NativeWindow? _native;
  bool _revealed = false;
  bool _disposed = false;

  /// runner 关门专线是否已挂上（init 后有效）— 诊断/测试观察位。
  @visibleForTesting
  bool hostCloseBridgeInstalled = false;

  /// 平台画像 — 诊断/测试观察位（UI 经 [needsResizeHotZones] 消费门控）。
  WindowPlatformProfile get platformProfile => _profile;

  @override
  bool get needsResizeHotZones => _profile.needsResizeHotZones;

  /// 最近一次普通窗口矩形的跟踪器 — 落盘的唯一几何来源（契约 9）。
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

  late final ResizeSession _session = ResizeSession(
    isResizing: isResizing,
    sessionId: resizeSessionId,
    onSettled: _onResizeSettled,
  );

  late final ModeController _modeController = ModeController(
    mode: mode,
    window: () => _native,
  );

  late final PersistQueue _persistQueue = PersistQueue(
    persistence: _persistence,
    bounds: _bounds,
    mode: mode,
    isAlwaysOnTop: isAlwaysOnTop,
    supportsWindowPositioning: _profile.supportsWindowPositioning,
    isDisposed: () => _disposed,
  );

  late final GeometryRestore _geometryRestore = GeometryRestore(
    supportsPositioning: _profile.supportsWindowPositioning,
  );

  final List<Future<void> Function()> _closingListeners = [];

  late final CloseSequence _closeSequence = CloseSequence(
    hide: () => _native?.hide(),
    persist: () async {
      // 先等排队中的落盘，避免与关窗落盘交错写同一份快照。
      await _persistQueue.drain();
      await _persistQueue.persistNow();
    },
    closingListeners: () => _closingListeners,
    disposeService: dispose,
    exit: _exitOnClose,
  );

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
      KernelLogger.I.e('[WindowService.init] $error\n$stackTrace');
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _initOnce() async {
    final window = _native ??= _bindWindow();
    // Win10 去 DWM frame 防主题色顶线；先于 hideTitleBar，让原生只重算一次 frame。
    if (_profile.dropDwmFrame) window.hasShadow = false;
    window.hideTitleBar();
    window.minimumSize = minimumWindowSize;
    // 关门专线注册：用户发起的关窗（Alt+F4/Cmd+W/Cmd+Q/delete-event）→
    // _beginClose（hide-first persist→exit）。注册失败（旧 runner 产物/符号
    // 缺失）仅记日志 — runner 侧放行原生关闭，✕ 按钮的 Dart close() 不受影响。
    hostCloseBridgeInstalled = _installCloseNotifier(
      () => unawaited(_beginClose()),
    );

    final persisted = await _persistence.load();
    if (_disposed) return;
    _bounds.value = _geometryRestore.restore(window, persisted);
    window.isAlwaysOnTop = persisted.alwaysOnTop;
    if (persisted.isMaximized) {
      // 隐藏态 maximize 只记「显示即最大化」标记，不会提前亮窗；runner 首帧
      // Show 直接以最大化形态出现，无普通→最大化闪变。命令同步 marshal，
      // reveal 时按 mode 意图值补发（见 reveal）。
      window.maximize();
    }
    isAlwaysOnTop.value = persisted.alwaysOnTop;
    mode.value = persisted.isMaximized
        ? WindowMode.maximized
        : WindowMode.windowed;
  }

  /// 亮窗 — 首帧栅格化后由组合根调用（v0.0.4 空白窗口修复）。
  /// show + 条件 maximize + focus；同时解除 init 阶段的几何信号抑制。
  Future<void> reveal() async {
    if (_disposed) return;
    _revealed = true;
    final window = _bound..show();
    if (mode.value.isMaximized) {
      window.maximize();
    }
    window.focus();
  }

  /// 降级亮窗 — init/reveal 失败时组合根 best-effort 调用。
  /// 宿主未绑定时无窗口可操作；runner 首帧回调仍会亮窗。
  Future<void> showDegraded() {
    _native?.show();
    return Future<void>.value();
  }

  // --- resize 会话（检测源：引擎指标，契约 2/3/6） ---

  /// 视图尺寸实际变化（引擎指标，来自 [WindowMetricsObserver]）— 拖拽会话
  /// 的默认检测源。didChangeMetrics 由引擎按帧合并，频率远低于原生事件
  /// 洪泛，且不占窗口线程。reveal 前吞掉（契约 6）。
  void noteGeometryChanged() {
    if (_disposed || !_revealed) return;
    // 还原矩形跟踪（tracker 内建节流，60Hz 指标率下开销可忽略）。
    _bounds.noteChanged();
    // 尺寸变化顺带校准一次模式（外部最大化/还原不再依赖事件）。
    _modeController.syncFromNative(revealed: _revealed);
    _session.noteChanged();
  }

  /// 会话结算（ResizeSession 防抖到期，isResizing 已翻 false）。
  void _onResizeSettled() {
    if (_disposed) return;
    // 会话结束再校准一次：覆盖"拖拽中途 isMaximized 翻转但无新指标"的边角。
    _modeController.syncFromNative(revealed: _revealed);
    // 全屏进入/退出触发的 resize 是过渡而非用户意图 — 不落盘。
    if (!mode.value.isFullscreen) _persistQueue.schedule();
  }

  // --- 模式切换 / 置顶 / 最小化 / 拖动（WindowBridge 转发） ---

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed) return;
    await _modeController.setMode(target);
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    final window = _native;
    if (_disposed || window == null || value == isAlwaysOnTop.value) return;
    window.isAlwaysOnTop = value;
    isAlwaysOnTop.value = value;
    _persistQueue.schedule();
  }

  @override
  Future<void> minimize() async {
    if (_disposed) return;
    _native?.minimize();
  }

  @override
  Future<void> startDragging() async {
    // 降级模式（init 失败）下窗口未绑定 — 手势回调静默无效，不抛。
    if (!_disposed) _native?.startDragging();
  }

  @override
  void startResizing(WindowResizeEdge edge) {
    if (!_disposed) _native?.startResizing(edge);
  }

  @override
  void titleBarDoubleClick() {
    if (!_disposed) _native?.performTitleBarDoubleClick();
  }

  // --- 关窗时序（hide-first，契约 7） ---

  @override
  Future<void> close() async {
    if (_disposed) return;
    await _beginClose();
  }

  /// 关窗时序的唯一入口 — 重复触发（✕ 连点 / 外部专线回调）共享同一次执行。
  Future<void> _beginClose() {
    _session.cancel();
    return _closeSequence.begin();
  }

  @override
  void Function() addClosingListener(Future<void> Function() listener) {
    _closingListeners.add(listener);
    // 移除函数幂等 — remove 对不存在元素是 no-op，重复调用安全。
    return () => _closingListeners.remove(listener);
  }

  // --- 持久化 / 测试观察位 ---

  /// 当前排队中的落盘 — 测试等待落盘完成用，避免依赖真实延时。
  @visibleForTesting
  Future<void> get pendingPersist => _persistQueue.pending;

  /// 关窗序列的执行体 — 测试等待关窗完成用。
  @visibleForTesting
  Future<void>? get closeOperation => _closeSequence.operation;

  // --- 释放 ---

  /// 释放窗口资源；重复调用安全。关窗序列末尾自动调用。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session.cancel();
    _bounds.dispose();
    _native?.dispose();
    mode.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
