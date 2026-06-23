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

import 'package:window_manager/window_manager.dart';

import '../utils/log.dart';
import 'platform_fullscreen.dart';
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
  })  : _platform = platform,
        _ops = ops ?? RealWindowOps();

  final WindowState state;
  final PlatformFullscreen _platform;
  final WindowOps _ops;

  // ─── Mutex guard ───

  bool _isAnimating = false;

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
      logBridge.d('[FullscreenController] blocked by mutex');
      return;
    }

    try {
      _isAnimating = true;

      if (enter) {
        await _saveWindowState();
        _savedSnapshot = await _platform.enter();
        state.mode.value = WindowMode.fullscreen;
      } else {
        final previousMode = _savedMode ?? WindowMode.windowed;
        if (_savedSnapshot != null) {
          _platform.exit(_buildExitSnapshot());
        }
        // 同步窗口大小到状态（退出全屏后 UI 需要正确的尺寸）
        if (_savedSize != null) {
          state.windowSize.value = _savedSize!;
        }
        _clearSavedState();
        state.mode.value = previousMode;
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
        state.mode.value = WindowMode.windowed;
      }
    } finally {
      _isAnimating = false;
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
  FullscreenSnapshot _buildExitSnapshot() {
    return FullscreenSnapshot(
      windowStyle: _savedSnapshot!.windowStyle,
      position: _savedPosition ?? _savedSnapshot!.position,
      size: _savedSize ?? _savedSnapshot!.size,
    );
  }
}
