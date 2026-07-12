/// 高风险回归测试套件 — 覆盖 D-35 高风险场景。
///
/// 测试目标:
/// - 快速连按 F 10/20 次不出现状态错位
/// - fullscreen -> exit 恢复正确状态
/// - enter 失败后重试可恢复
/// - fast path 直接确认行为
/// - per-window 隔离（独立 WindowService 互不污染）
///
/// v3 简化: DesktopFullscreenAdapter 已合并入 WindowService。
/// 测试通过 WindowService + MockFullscreenDriver（fast path）验证。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/window_service.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_capability.dart';

// ─── 测试替身 ───

/// Mock FullscreenDriver — fast path 模式，跳过确认链和 windowManager 调用。
class _MockFullscreenDriver extends FullscreenDriver {
  final List<String> calls = [];

  Exception? throwOnEnter;

  @override
  bool get supportsFastPath => true;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    calls.add('enterFullscreen(displayId: $displayId)');
    if (throwOnEnter != null) throw throwOnEnter!;
  }

  @override
  Future<void> leaveFullscreen() async {
    calls.add('leaveFullscreen()');
  }

  @override
  Future<bool> queryFullscreen() async {
    calls.add('queryFullscreen()');
    return false;
  }

  @override
  Future<void> enterFullscreenFast({int displayId = 0}) async {
    calls.add('enterFullscreenFast(displayId: $displayId)');
    if (throwOnEnter != null) throw throwOnEnter!;
  }

  @override
  Future<void> leaveFullscreenFast() async {
    calls.add('leaveFullscreenFast()');
  }

  @override
  void clearMonitorCache() {}

  @override
  void dispose() {}

  @override
  FullscreenCapability capabilities() => const FullscreenCapability();
}

// ─── 高风险测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('High Risk Suite', () {
    late _MockFullscreenDriver driver;
    late WindowService service;

    setUp(() {
      // 注册 window_manager channel 的 fake handler，
      // 避免 MissingPluginException（_captureRestoreSnapshot / _handleEnter 调用）
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          switch (call.method) {
            case 'getBounds':
              return <String, dynamic>{
                'x': 0.0,
                'y': 0.0,
                'width': 1920.0,
                'height': 1080.0,
              };
            case 'isMaximized':
              return false;
            case 'isMinimized':
              return false;
            default:
              return null;
          }
        },
      );
      driver = _MockFullscreenDriver();
      service = WindowService(driver: driver);
    });

    tearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    // HR-001: 快速连按 F 10 次 — 验证最终状态正确
    test('rapid toggle 10 times ends in correct state', () async {
      for (var i = 0; i < 10; i++) {
        if (service.isFullscreen) {
          await service.setMode(WindowMode.windowed);
        } else {
          await service.setMode(WindowMode.fullscreen);
        }
      }

      // 10 次 toggle（偶数）从 windowed 开始 → 最终 windowed
      expect(service.isFullscreen, isFalse);
    });

    // HR-002: 快速连按 F 20 次 — 验证不崩溃
    test(
      'rapid toggle 20 times does not crash',
      () async {
        for (var i = 0; i < 20; i++) {
          if (service.isFullscreen) {
            await service.setMode(WindowMode.windowed);
          } else {
            await service.setMode(WindowMode.fullscreen);
          }
        }

        // 20 次 toggle（偶数）后应恢复到稳定状态
        expect(service.isFullscreen, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    // HR-003: fullscreen -> exit 验证状态恢复
    test('fullscreen -> exit restores windowed state', () async {
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      await service.setMode(WindowMode.windowed);
      expect(service.isFullscreen, isFalse);

      // 验证 driver 调用了正确的 enter/leave
      expect(driver.calls, contains('enterFullscreenFast(displayId: 0)'));
      expect(driver.calls, contains('leaveFullscreenFast()'));
    });

    // HR-004: StateDesync 后手动重试可恢复
    // 模拟：enter 失败 → 重试 enter 成功
    test('StateDesync recovery: fail then retry succeeds', () async {
      // 第一次 enter 失败（模拟平台异常）
      driver.throwOnEnter = Exception('platform failure');
      await service.setMode(WindowMode.fullscreen);
      // 失败后 isFullscreen 应为 false
      expect(service.isFullscreen, isFalse);

      // 修复平台，重试 enter
      driver.throwOnEnter = null;
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);
    });

    // HR-005: fast path 直接确认 — enterFullscreenFast 直接完成
    test('fast path enter completes without polling', () async {
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      // fast path 应该调用 enterFullscreenFast 而非 enterFullscreen
      expect(driver.calls, contains('enterFullscreenFast(displayId: 0)'));
      // 不应调用普通 enterFullscreen
      expect(
        driver.calls.any((c) => c == 'enterFullscreen(displayId: 0)'),
        isFalse,
      );
    });

    // HR-006: per-window 隔离 — 两个独立 WindowService 互不污染
    test('per-window isolation: two services do not interfere', () async {
      final driver1 = _MockFullscreenDriver();
      final driver2 = _MockFullscreenDriver();
      final service1 = WindowService(driver: driver1);
      final service2 = WindowService(driver: driver2);

      try {
        // service1 进入全屏
        await service1.setMode(WindowMode.fullscreen);
        expect(service1.isFullscreen, isTrue);
        // service2 应保持 windowed
        expect(service2.isFullscreen, isFalse);

        // service2 进入全屏
        await service2.setMode(WindowMode.fullscreen);
        expect(service2.isFullscreen, isTrue);
        // service1 仍为 fullscreen
        expect(service1.isFullscreen, isTrue);

        // service1 退出全屏
        await service1.setMode(WindowMode.windowed);
        expect(service1.isFullscreen, isFalse);
        // service2 仍为 fullscreen
        expect(service2.isFullscreen, isTrue);

        // service2 退出全屏
        await service2.setMode(WindowMode.windowed);
        expect(service2.isFullscreen, isFalse);
      } finally {
        service1.dispose();
        service2.dispose();
      }
    });
  });
}
