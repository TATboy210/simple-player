import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../services/platform_service.dart';

/// 窗口管理服务 — Singleton，封装 window_manager
///
/// Reactive state 通过 ValueNotifier 暴露，UI 用 ValueListenableBuilder 绑定。
/// 不注册 DI（全局唯一原生资源，EventBus.I 同级模式）。
///
/// 生产加固:
/// - 500ms 去抖持久化（避免拖拽/调整大小时频繁写入）
/// - 窗口位置边界检查（多显示器→单显示器场景）
/// - setPreventClose + destroy 安全关闭（确保磁盘写入完成）
/// - Completer 竞态修复（dispose 等待 init 完成）
/// - 所有 FFI 调用 try-catch 防御
/// - 全屏时不保存全屏尺寸
class WindowManagerService implements WindowListener {
  WindowManagerService._();
  static final WindowManagerService I = WindowManagerService._();

  // ─── Reactive State ───

  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  final isMaximized = ValueNotifier<bool>(false);

  /// resize 进行中标记 — UI 用于降级渲染（跳过 BackdropFilter）
  final isResizing = ValueNotifier<bool>(false);

  // ─── Constants ───

  static const minSize = Size(1024, 576); // 576p 16:9
  static const _completerTimeoutSeconds = 5;

  /// 拖拽结束后等待此时间才重置 isResizing，防止慢速拖拽时 BackdropFilter 闪烁
  static const _resizeDebounceMs = 500;
  static const _persistDebounceMs = 500;
  static const _redrawChannel = MethodChannel('com.simple_player/redraw');

  // ─── Internal ───

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;
  Completer<void>? _closeCompleter;

  /// 去抖 Timer: 连续 resize/move 事件合并为 500ms 后的一次写入
  Timer? _persistDebounce;

  /// resize 结束去抖：松手后 100ms 才设 isResizing=false（避免最后一帧闪烁）
  Timer? _resizeEndDebounce;

  /// 缓存窗口化几何（全屏时用于恢复，避免磁盘读取）
  Size _windowedSize = Size.zero;
  Offset _windowedPosition = Offset.zero;

  /// 全屏切换重入守卫 — 防止快速 F11 导致 ABA 状态损坏
  bool _togglingFullscreen = false;

  /// 持久化进行中守卫 — 防止并发 _persistWindowState
  Completer<void>? _persistInFlight;

  /// 持久化合并标记 — 持久化进行中又有新请求时设为 true，finally 中重新持久化
  bool _persistRequested = false;

  /// 关闭守卫 — 防止 onWindowClose 双击触发重复关闭
  bool _closing = false;

  // ─── Lifecycle ───

  Future<void> init() async {
    if (_initialized) return;
    _initCompleter = Completer<void>();

    await windowManager.ensureInitialized();

    final settings = await SettingsStore.load();
    final savedSize = Size(settings.windowWidth, settings.windowHeight);
    _windowedSize = savedSize;
    _windowedPosition = settings.windowX != null
        ? Offset(settings.windowX!, settings.windowY!)
        : Offset.zero;

    final windowOptions = WindowOptions(
      size: savedSize,
      minimumSize: minSize,
      center: settings.windowX == null,
      // 纯黑背景：避免 transparent + frameless 首帧伪影
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // RC-2: 防止 dispose() 后僵尸回调重新初始化服务
      if (_disposed) return;
      try {
        // DWMWA_USE_IMMERSIVE_DARK_MODE 在 win32_window.cpp 中已设置
        if (settings.windowX != null && settings.windowY != null) {
          await windowManager.setPosition(
            Offset(settings.windowX!, settings.windowY!),
          );
          await _clampToVisibleBounds(
            savedSize,
            Offset(settings.windowX!, settings.windowY!),
          );
        }

        // 恢复最大化
        if (settings.isMaximized) {
          await windowManager.maximize();
        }

        // 恢复 always-on-top
        if (settings.isAlwaysOnTop) {
          await windowManager.setAlwaysOnTop(true);
          isAlwaysOnTop.value = true;
        }

        // 安全关闭: 拦截关闭事件，确保持久化完成后再销毁
        await windowManager.setPreventClose(true);

        await _prepareFramelessFirstFrame();

        // 显示窗口（此时已是 frameless，无边框闪烁）
        await windowManager.show();
        await windowManager.focus();

        // 恢复全屏（在窗口显示 + frameless 确认后执行）
        if (settings.isFullscreen) {
          mode.value = WindowMode.fullscreen;
          await windowManager.setHasShadow(false);
          final screen = ui.PlatformDispatcher.instance.views.first;
          final screenW = screen.physicalSize.width / screen.devicePixelRatio;
          final screenH = screen.physicalSize.height / screen.devicePixelRatio;
          await windowManager.setPosition(Offset.zero);
          await windowManager.setSize(Size(screenW, screenH));
        }

        // RC-2: 再次检查 _disposed（await 期间可能已被 dispose）
        if (_disposed) {
          windowManager.removeListener(this);
          _initCompleter!.complete();
          return;
        }

        windowManager.addListener(this);
        // RC-10: 同步实际窗口状态（maximize 在 addListener 前执行，
        // onWindowMaximize 回调未被接收，需要主动查询）
        isMaximized.value = await windowManager.isMaximized();
        _initialized = true;
        _initCompleter!.complete();
      } on Exception catch (e) {
        debugPrint('[WindowManager] init callback failed: $e');
        if (!_initCompleter!.isCompleted) {
          _initCompleter!.completeError(e);
        }
      }
    });

    // RC-9: 等待 waitUntilReadyToShow 回调完成，确保 init() 返回时窗口已就绪
    await _initCompleter!.future;
  }

  Future<void> _prepareFramelessFirstFrame() async {
    // 无边框 + 阴影：在 show() 前设置（原生 Show() 已移除，窗口不可见）
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(true);

    // 首帧黑块/错位修复仅针对 Windows，其他平台跳过额外原生往返调用。
    if (!Platform.isWindows) return;

    // 某些 Windows 机器在首次切换 frameless 后不会立即触发 Flutter 视图重布局，
    // 会出现顶部黑块/首帧错位。这里用一次 noop setSize 强制触发 WM_SIZE。
    try {
      final size = await windowManager.getSize();
      if (size.width > 0 && size.height > 0) {
        await windowManager.setSize(size);
      }
    } on Exception catch (e) {
      debugPrint('[WindowManager] force layout after frameless failed: $e');
    }

    // 在 frameless 客户区尺寸下强制重绘首帧，
    // 避免 Flutter 以 TitleBarStyle.hidden 的 8px 边框尺寸渲染
    try {
      await _redrawChannel.invokeMethod('forceRedraw');
    } on MissingPluginException {
      // channel 未注册（热重载竞态），安全跳过
    } catch (e) {
      debugPrint('[WindowManager] forceRedraw error: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true; // RC-2: 防止 waitUntilReadyToShow 僵尸回调
    _persistDebounce?.cancel();
    _resizeEndDebounce?.cancel();

    // 等待 init 完成（5s 超时兜底，防止永久阻塞）
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      try {
        await _initCompleter!.future.timeout(
          const Duration(seconds: _completerTimeoutSeconds),
        );
      } catch (_) {
        // 超时或出错，强制继续清理
      }
    }

    if (_initialized) {
      windowManager.removeListener(this);
      await _persistWindowState();
      _initialized = false;
    }

    // RC-1: 等待 onWindowClose 中的异步操作完成（5s 超时兜底）
    if (_closeCompleter != null && !_closeCompleter!.isCompleted) {
      try {
        await _closeCompleter!.future.timeout(
          const Duration(seconds: _completerTimeoutSeconds),
        );
      } catch (_) {
        // 超时或出错，强制继续
      }
    }
  }

  // ─── Window Controls ───

  Future<void> minimize() async {
    try {
      await windowManager.minimize();
    } on Exception catch (e) {
      debugPrint('[WindowManager] minimize failed: $e');
    }
  }

  Future<void> toggleMaximize() async {
    try {
      if (isMaximized.value) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on Exception catch (e) {
      debugPrint('[WindowManager] toggleMaximize failed: $e');
    }
  }

  Future<void> close() async {
    try {
      await windowManager.close();
    } on Exception catch (e) {
      debugPrint('[WindowManager] close failed: $e');
    }
  }

  Future<void> startDragging() async {
    try {
      await windowManager.startDragging();
    } on Exception catch (e) {
      debugPrint('[WindowManager] startDragging failed: $e');
    }
  }

  // ─── Fullscreen ───

  Future<void> toggleFullscreen() async {
    // RC-5: 重入守卫 — 防止快速 F11 导致 ABA 状态损坏
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      if (mode.value == WindowMode.fullscreen) {
        await _exitFullscreenInternal();
      } else {
        // 缓存窗口化几何（退出全屏时恢复）
        _windowedSize = await windowManager.getSize();
        _windowedPosition = await windowManager.getPosition();
        mode.value = WindowMode.fullscreen; // 乐观更新
        try {
          await windowManager.setHasShadow(false);
          // 手动全屏：setSize + setPosition 覆盖整个屏幕
          // （setFullScreen 在 frameless 窗口上可能不正确扩展）
          final screen = ui.PlatformDispatcher.instance.views.first;
          final screenW = screen.physicalSize.width / screen.devicePixelRatio;
          final screenH = screen.physicalSize.height / screen.devicePixelRatio;
          await windowManager.setPosition(Offset.zero);
          await windowManager.setSize(Size(screenW, screenH));
          await SettingsStore.saveIsFullscreen(true);
        } on Exception catch (e) {
          mode.value = WindowMode.windowed; // 回滚
          debugPrint('[WindowManager] enterFullscreen failed: $e');
        }
      }
    } finally {
      _togglingFullscreen = false;
    }
  }

  Future<void> exitFullscreen() async {
    // RC-5: 重入守卫 — 外部直接调用时防快速重复
    if (_togglingFullscreen) return;
    _togglingFullscreen = true;
    try {
      await _exitFullscreenInternal();
    } finally {
      _togglingFullscreen = false;
    }
  }

  /// 退出全屏核心逻辑（无重入守卫，供 toggleFullscreen 内部调用）
  Future<void> _exitFullscreenInternal() async {
    mode.value = WindowMode.windowed; // 乐观更新
    try {
      // 恢复窗口化尺寸和位置
      await windowManager.setSize(_windowedSize);
      await windowManager.setPosition(_windowedPosition);
      await windowManager.setHasShadow(true);
      await SettingsStore.saveIsFullscreen(false);
    } on Exception catch (e) {
      mode.value = WindowMode.fullscreen; // 回滚
      debugPrint('[WindowManager] exitFullscreen failed: $e');
    }
  }

  // ─── Always on Top ───

  Future<void> toggleAlwaysOnTop() async {
    try {
      final next = !isAlwaysOnTop.value;
      await windowManager.setAlwaysOnTop(next);
      isAlwaysOnTop.value = next;
      await SettingsStore.saveIsAlwaysOnTop(next);
    } on Exception catch (e) {
      debugPrint('[WindowManager] toggleAlwaysOnTop failed: $e');
    }
  }

  // ─── WindowListener ───

  @override
  void onWindowMaximize() {
    isMaximized.value = true;
    _persistWindowState(); // 离散状态，立即持久化
  }

  @override
  void onWindowUnmaximize() {
    isMaximized.value = false;
    _persistWindowState(); // 离散状态，立即持久化
  }

  @override
  void onWindowEnterFullScreen() {
    // 幂等确认：toggleFullscreen 已乐观设置
    mode.value = WindowMode.fullscreen;
  }

  @override
  void onWindowLeaveFullScreen() {
    // 幂等确认：exitFullscreen 已乐观设置
    mode.value = WindowMode.windowed;
  }

  @override
  void onWindowResize() {
    _resizeEndDebounce?.cancel(); // 取消待定的重置，防止拖拽期间闪烁
    isResizing.value = true;
  }

  @override
  void onWindowResized() {
    _schedulePersist(); // "after" 回调: 去抖持久化
    _resizeEndDebounce?.cancel();
    _resizeEndDebounce = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () => isResizing.value = false,
    );
  }

  @override
  void onWindowMove() {} // "during" 回调: 不持久化

  @override
  void onWindowMoved() {
    _schedulePersist(); // "after" 回调: 去抖持久化
  }

  @override
  void onWindowClose() {
    if (_closing) return;
    _closing = true;
    // RC-1: 同步入口 → 异步工作通过 Completer 暴露给 dispose() 等待
    _closeCompleter = Completer<void>();
    _persistDebounce?.cancel();
    _persistWindowState()
        .then((_) {
          return windowManager.destroy();
        })
        .then((_) {
          _closeCompleter!.complete();
        })
        .catchError((Object e) {
          debugPrint('[WindowManager] close sequence failed: $e');
          if (!_closeCompleter!.isCompleted) {
            _closeCompleter!.completeError(e);
          }
        });
  }

  // 其他 WindowListener 回调（空实现）
  @override
  void onWindowEvent(String eventName) {}
  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}

  // ─── Persistence ───

  /// 去抖持久化: 连续 resize/move 事件合并为 500ms 后的一次写入
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: _persistDebounceMs),
      _persistWindowState,
    );
  }

  /// 持久化窗口状态到 SharedPreferences
  ///
  /// 4 个 FFI 查询并行执行（Future.wait），减少 ~75% 延迟。
  /// 全屏时不保存全屏尺寸 — 用内存缓存的窗口化几何，避免磁盘读取。
  /// RC-7: _persistInFlight 防止并发写入导致数据竞争。
  Future<void> _persistWindowState() async {
    // RC-7: 如果已有持久化在进行中，标记待重试而非丢弃
    if (_persistInFlight != null) {
      _persistRequested = true;
      return _persistInFlight!.future;
    }
    _persistInFlight = Completer<void>();
    _persistRequested = false;
    try {
      final results = await Future.wait([
        windowManager.getSize(),
        windowManager.getPosition(),
        windowManager.isMaximized(),
        windowManager.isFullScreen(),
      ]);
      final size = results[0] as Size;
      final position = results[1] as Offset;
      final maximized = results[2] as bool;
      final fullscreen = results[3] as bool;

      if (!fullscreen) {
        // 窗口化：更新缓存 + 写磁盘
        _windowedSize = size;
        _windowedPosition = position;
        await SettingsStore.saveWindowGeometry(
          width: size.width,
          height: size.height,
          x: position.dx,
          y: position.dy,
          isMaximized: maximized,
        );
      } else {
        // 全屏：用缓存值，只更新 isMaximized
        await SettingsStore.saveWindowGeometry(
          width: _windowedSize.width,
          height: _windowedSize.height,
          x: _windowedPosition.dx,
          y: _windowedPosition.dy,
          isMaximized: maximized,
        );
      }
      _persistInFlight!.complete();
    } on Exception catch (e) {
      debugPrint('[WindowManager] persist failed: $e');
      // 错误已通过 debugPrint 记录，正常完成 Completer（避免无人 await 导致未处理异常）
      if (!_persistInFlight!.isCompleted) {
        _persistInFlight!.complete();
      }
    } finally {
      _persistInFlight = null;
      // PQ-04: 持久化进行中有新请求时，重新持久化最新状态
      if (_persistRequested) {
        _persistRequested = false;
        _persistWindowState();
      }
    }
  }

  // ─── Bounds Check ───

  /// 首次恢复时检查: 如果保存的位置在当前屏幕可见区域之外，则居中显示
  ///
  /// 使用 PlatformDispatcher 获取主显示器逻辑尺寸，判断窗口是否至少有
  /// 100px 可见区域。覆盖多显示器→单显示器切换、DPI 变化等场景。
  Future<void> _clampToVisibleBounds(
    Size savedSize,
    Offset savedPosition,
  ) async {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final screenW = view.physicalSize.width / view.devicePixelRatio;
      final screenH = view.physicalSize.height / view.devicePixelRatio;
      const double minVisible = 100; // 至少 100px 可见

      final isOffScreen =
          savedPosition.dx + savedSize.width < minVisible ||
          savedPosition.dy + savedSize.height < minVisible ||
          savedPosition.dx > screenW - minVisible ||
          savedPosition.dy > screenH - minVisible;

      if (isOffScreen) {
        await windowManager.center();
      }
    } on Exception catch (e) {
      // 居中失败不应阻止启动
      debugPrint('[WindowManager] bounds check failed: $e');
    }
  }
}
