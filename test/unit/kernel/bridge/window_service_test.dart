import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_service.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('WindowService composition', () {
    test('state.mode defaults to windowed', () {
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('mode getter delegates to state.mode', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.state.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('state windowSize defaults to 1280x752', () {
      final service = WindowService();
      expect(service.state.windowSize.value.width, 1280);
      expect(service.state.windowSize.value.height, 752);
      service.dispose();
    });
  });

  group('WindowListener callbacks', () {
    test('onWindowMaximize sets mode to maximized', () {
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.state.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize sets mode to windowed', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

  });

  group('dispose safety', () {
    test('callback after dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });

    test('double dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // ─── Driver creation (Task 2) ───

  group('driver creation', () {
    test('WindowService() creates with internal driver (no crash)', () {
      // 测试环境 HWND=0，_createDriver 应返回 null（不崩溃）
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('WindowService(driver: mock) accepts injected driver', () {
      // 注入假驱动 — 验证构造函数接受 driver 参数且不崩溃
      final fake = _FakeFullscreenDriver();
      final service = WindowService(driver: fake);
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });
  });

  // ─── FullscreenResult sealed class (Task 2) ───

  group('FullscreenResult sealed class', () {
    test('FullscreenSuccess is a FullscreenResult', () {
      const result = FullscreenSuccess();
      expect(result, isA<FullscreenResult>());
    });

    test('FullscreenFailure is a FullscreenResult', () {
      const result = FullscreenFailure();
      expect(result, isA<FullscreenResult>());
    });

    test('FullscreenFailure defaults restored to false', () {
      const result = FullscreenFailure();
      expect(result.restored, isFalse);
    });

    test('FullscreenFailure accepts restored parameter', () {
      const result = FullscreenFailure(restored: true);
      expect(result.restored, isTrue);
    });
  });

  // ─── Confirmation chain simplification (Task 2) ───

  group('confirmation chain', () {
    test('setMode fullscreen with failure restores mode', () async {
      // 测试环境 windowManager 未注册，setMode fullscreen 会抛 MissingPluginException
      // _handleEnter 捕获异常返回 FullscreenFailure，setMode 应恢复 mode 为 windowed
      final fake = _FakeFullscreenDriver();
      final service = WindowService(driver: fake);
      final before = service.state.mode.value;
      await service.setMode(WindowMode.fullscreen);
      expect(service.state.mode.value, before);
      service.dispose();
    });

    test('setMode fullscreen with driver exception returns failure', () async {
      // 驱动抛异常时 _handleEnter 应返回 FullscreenFailure
      final fake = _FakeFullscreenDriver(shouldThrow: true);
      final service = WindowService(driver: fake);
      await service.setMode(WindowMode.fullscreen);
      // 异常导致 FullscreenFailure，setMode 恢复 mode
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });
  });

  // ─── isFullscreen derivation from mode (Task 2) ───

  group('isFullscreen derives from mode', () {
    test('isFullscreen returns false when mode is windowed', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isFullscreen returns true when mode is fullscreen', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test('isFullscreen tracks mode changes', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.state.mode.value = WindowMode.windowed;
      expect(service.isFullscreen, isFalse);
      service.dispose();
    });
  });
}

/// 测试用假驱动 — 支持 fast-path 标志和异常模拟。
class _FakeFullscreenDriver extends FullscreenDriver {
  _FakeFullscreenDriver({
    this.supportsFastPath = false,
    this.shouldThrow = false,
  });

  final bool shouldThrow;

  @override
  final bool supportsFastPath;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    if (shouldThrow) throw Exception('simulated failure');
  }

  @override
  Future<void> leaveFullscreen() async {
    if (shouldThrow) throw Exception('simulated failure');
  }

  @override
  Future<bool> queryFullscreen() async => false;
}
