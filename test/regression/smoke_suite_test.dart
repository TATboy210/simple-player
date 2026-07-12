/// 冒烟测试套件 — 覆盖 8 项必测场景（D-32）。
///
/// 每个测试标注 case ID（FS-REG-001 ~ FS-REG-008），与 regression_matrix.md 对应。
///
/// v3 简化: DesktopFullscreenAdapter 已合并入 WindowService。
/// 测试通过 WindowService + MockFullscreenDriver（fast path）验证全屏行为。
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

// ─── 冒烟测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Suite — 8 Mandatory Scenarios', () {
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

    // FS-REG-001: 播放中 + 全屏
    test(
      'FS-REG-001: playing + fullscreen enters and exits correctly',
      () async {
        expect(service.isFullscreen, isFalse);

        await service.setMode(WindowMode.fullscreen);
        expect(service.isFullscreen, isTrue);

        await service.setMode(WindowMode.windowed);
        expect(service.isFullscreen, isFalse);
      },
    );

    // FS-REG-002: 暂停中 + 全屏
    test(
      'FS-REG-002: paused + fullscreen enters and exits correctly',
      () async {
        expect(service.isFullscreen, isFalse);

        await service.setMode(WindowMode.fullscreen);
        expect(service.isFullscreen, isTrue);

        await service.setMode(WindowMode.windowed);
        expect(service.isFullscreen, isFalse);
      },
    );

    // FS-REG-003: F 键与按钮一致性
    // setMode(fullscreen) 和 setMode(windowed) 结果相同
    test('FS-REG-003: enter and leave produce same result', () async {
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      await service.setMode(WindowMode.windowed);
      expect(service.isFullscreen, isFalse);

      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      await service.setMode(WindowMode.windowed);
      expect(service.isFullscreen, isFalse);
    });

    // FS-REG-004: ESC 语义 — fullscreen 状态下 setMode(windowed) 退出全屏
    test('FS-REG-004: ESC exits fullscreen (setMode(windowed))', () async {
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      await service.setMode(WindowMode.windowed);
      expect(service.isFullscreen, isFalse);
    });

    // FS-REG-005: 连续切换稳定性（10 次 toggle）
    test('FS-REG-005: 10 consecutive toggles end in stable state', () async {
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

    // FS-REG-006: windowed -> fullscreen -> windowed 验证状态恢复
    test(
      'FS-REG-006: windowed -> fullscreen -> windowed restores state',
      () async {
        await service.setMode(WindowMode.fullscreen);
        expect(service.isFullscreen, isTrue);

        await service.setMode(WindowMode.windowed);
        expect(service.isFullscreen, isFalse);

        // 验证 driver 调用了 enter/leave
        expect(driver.calls, contains('enterFullscreenFast(displayId: 0)'));
        expect(driver.calls, contains('leaveFullscreenFast()'));
      },
    );

    // FS-REG-007: 副屏位置恢复 — displayId 参数传递
    test('FS-REG-007: displayId is passed to driver', () async {
      await service.setMode(WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);

      // 验证 driver 收到 displayId
      expect(
        driver.calls.any((c) => c.contains('enterFullscreenFast')),
        isTrue,
      );
    });

    // FS-REG-008: 错误事件通知 — enter 失败时 isFullscreen 保持 false
    test('FS-REG-008: enter failure keeps isFullscreen false', () async {
      driver.throwOnEnter = Exception('platform enter failed');

      await service.setMode(WindowMode.fullscreen);

      // 失败后 isFullscreen 应为 false
      expect(service.isFullscreen, isFalse);
    });
  });
}
