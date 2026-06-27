/// 全屏控制器 — 通过 PlatformFullscreen 接口操作平台特定全屏。
///
/// 设计原则:
/// - 实例级状态，无全局可变变量
/// - try/finally mutex 保证异常时解锁
/// - 失败时回滚到保存的窗口状态
/// - 通过 WindowState.mode 读写模式（OS 回调驱动）
/// - WindowManager 操作可注入（测试用 FakeWindowOps）
/// - 平台全屏操作可注入（测试用 FakePlatformFullscreen）
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'display_enumerator.dart';
import 'platform_fullscreen.dart';
import 'win32/win32_display_enumerator.dart';
import 'window_mode.dart';
import 'window_state.dart';

// ─── WindowManager 操作抽象（可注入测试替身） ───

/// 窗口矩形。
class WindowRect {
  const WindowRect(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
}

/// WindowManager 操作抽象 — 测试时注入 FakeWindowOps。
abstract class WindowOps {
  Future<bool> isFullScreen();
  Future<void> setFullScreen(bool value);
  Future<Offset> getPosition();
  Future<void> setPosition(Offset position);
  Future<Size> getSize();
  Future<void> setSize(Size size);
}

/// 真实 WindowManager 操作。
class RealWindowOps implements WindowOps {
  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);

  @override
  Future<Offset> getPosition() => windowManager.getPosition();

  @override
  Future<void> setPosition(Offset position) => windowManager.setPosition(position);

  @override
  Future<Size> getSize() => windowManager.getSize();

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);
}

/// 纯 Flutter 全屏控制器。
///
/// 使用:
/// ```dart
/// final ctrl = FullscreenController(state: windowState);
/// await ctrl.toggle(); // 进入全屏
/// await ctrl.toggle(); // 退出全屏（回滚到之前状态）
/// ```
class FullscreenController {
  FullscreenController({
    required this.state,
    required PlatformFullscreen platform,
    WindowOps? ops,
    DisplayEnumerator? displayEnumerator,
  })  : _platform = platform,
        _ops = ops ?? RealWindowOps(),
        _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter();

  final WindowState state;
  final PlatformFullscreen _platform;
  final WindowOps _ops;
  final DisplayEnumerator _displayEnumerator;

  // ─── Mutex guard + debounce ───

  bool _isAnimating = false;
  bool _pendingToggle = false;

  /// 是否正在执行全屏切换。
  bool get isAnimating => _isAnimating;

  // ─── Saved state for rollback ───

  WindowMode? _savedMode;
  Offset? _savedPosition;
  Size? _savedSize;
  FullscreenSnapshot? _savedSnapshot;

  // ─── Public API ───

  /// 切换全屏 — 读取当前 mode 决定进入/退出。
  Future<void> toggle() async {
    final target = !state.mode.value.isFullscreen;
    await setFullscreen(target);
  }

  /// 设置全屏状态。
  ///
  /// 通过 PlatformFullscreen 接口操作平台特定全屏。
  /// 使用 mutex try/finally 保证异常时解锁。
  /// 失败时回滚窗口位置和大小。
  Future<void> setFullscreen(bool enter) async {
    if (enter == state.mode.value.isFullscreen) return;
    if (_isAnimating) {
      _pendingToggle = true;
      logBridge.d('[FullscreenController] queued pending toggle');
      return;
    }

    try {
      _isAnimating = true;

      if (enter) {
        await _saveWindowState();
        _savedSnapshot = await _platform.enter();
        _safeUpdate(() => state.mode.value = WindowMode.fullscreen);
      } else {
        final previousMode = _savedMode ?? WindowMode.windowed;
        if (_savedSnapshot != null) {
          _platform.exit(_buildExitSnapshot());
        }
        // 同步窗口大小到状态（退出全屏后 UI 需要正确的尺寸）
        if (_savedSize != null) {
          _safeUpdate(() => state.windowSize.value = _savedSize!);
        }
        _clearSavedState();
        _safeUpdate(() => state.mode.value = previousMode);
      }
    } on Exception catch (e) {
      logBridge.e('[FullscreenController.setFullscreen] FAILED: $e');
      if (enter && _savedSnapshot != null) {
        try {
          _platform.exit(_buildExitSnapshot());
          _clearSavedState();
        } on Exception catch (rollbackError) {
          logBridge.e('[FullscreenController] ROLLBACK ALSO FAILED: $rollbackError');
          _clearSavedState();
        }
        _safeUpdate(() => state.mode.value = WindowMode.windowed);
      }
    } finally {
      _isAnimating = false;
      if (_pendingToggle) {
        _pendingToggle = false;
        toggle();
      }
    }
  }

  // ─── Thread safety ───

  /// 确保 ValueNotifier 更新在 UI 线程执行。
  ///
  /// PlatformFullscreen 的 MethodChannel 回调可能在 platform thread，
  /// 直接更新 ValueNotifier 会触发 notifyListeners() 跨线程崩溃。
  void _safeUpdate(VoidCallback update) {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        update();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) => update());
      }
    } catch (_) {
      // 测试环境或 binding 未初始化时直接执行
      update();
    }
  }

  // ─── Internal: save/restore/apply ───

  Future<void> _saveWindowState() async {
    _savedMode = state.mode.value;
    _savedPosition = await _ops.getPosition();
    _savedSize = await _ops.getSize();
  }

  void _clearSavedState() {
    _savedMode = null;
    _savedPosition = null;
    _savedSize = null;
    _savedSnapshot = null;
  }

  /// 构建退出全屏用的快照 — 合并平台快照和控制器保存的位置/大小。
  ///
  /// 恢复前钳制到最近显示器，防止窗口恢复到已断开的显示器。
  FullscreenSnapshot _buildExitSnapshot() {
    final snapshot = _savedSnapshot;
    if (snapshot == null) {
      throw StateError('No saved snapshot for fullscreen exit');
    }
    final pos = _savedPosition ?? snapshot.position;
    final size = _savedSize ?? snapshot.size;

    // 钳制到最近显示器 — 防止窗口恢复到已断开的显示器
    final displays = _displayEnumerator.enumerateDisplays();
    final clamped = ScreenUtils.clampToNearestMonitor(
      displays: displays,
      x: pos.dx,
      y: pos.dy,
      width: size.width,
      height: size.height,
    );

    return FullscreenSnapshot(
      windowStyle: snapshot.windowStyle,
      position: clamped,
      size: size,
    );
  }
}
