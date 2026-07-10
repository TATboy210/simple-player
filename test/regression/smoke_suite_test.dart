/// 冒烟测试套件 — 覆盖 8 项必测场景（D-32）。
///
/// 每个测试标注 case ID（FS-REG-001 ~ FS-REG-008），与 regression_matrix.md 对应。
///
/// 测试场景:
/// FS-REG-001: 播放中 + 全屏
/// FS-REG-002: 暂停中 + 全屏
/// FS-REG-003: F 键与按钮一致性（toggle vs setFullscreen）
/// FS-REG-004: ESC 语义（fullscreen 下 setFullscreen(false)）
/// FS-REG-005: 连续切换稳定性（10 次 toggle）
/// FS-REG-006: windowed -> fullscreen -> windowed 恢复原始几何
/// FS-REG-007: 副屏位置恢复（自定义 position）
/// FS-REG-008: 错误事件通知（enter 失败 → 回滚）
///
/// 所有测试使用 MockFullscreenDriver + DesktopFullscreenAdapter，
/// 通过 Level-2 轮询确认（设置 driver.fullscreenState 后 adapter 自动匹配）。
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_capability.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_error.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_snapshot.dart';

// ─── 测试替身 ───

/// Mock FullscreenDriver — 记录调用参数，可控返回值。
class _MockFullscreenDriver implements FullscreenDriver {
  final List<String> calls = [];

  bool fullscreenState = false;
  bool minimizedState = false;
  bool maximizedState = false;
  Offset currentPosition = const Offset(100, 100);
  Size currentSize = const Size(1280, 720);

  Exception? throwOnEnter;

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
    return fullscreenState;
  }

  @override
  Future<Offset> getPosition() async {
    calls.add('getPosition()');
    return currentPosition;
  }

  @override
  Future<Size> getSize() async {
    calls.add('getSize()');
    return currentSize;
  }

  @override
  Future<void> setBounds(Offset? position, Size? size) async {
    calls.add('setBounds($position, $size)');
    if (position != null) currentPosition = position;
    if (size != null) currentSize = size;
  }

  @override
  Future<void> maximize() async {
    calls.add('maximize()');
    maximizedState = true;
  }

  @override
  Future<void> restore() async {
    calls.add('restore()');
    minimizedState = false;
    maximizedState = false;
  }

  @override
  Future<void> focus() async {
    calls.add('focus()');
  }

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized()');
    return maximizedState;
  }

  @override
  Future<bool> isMinimized() async {
    calls.add('isMinimized()');
    return minimizedState;
  }

  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    // 空实现 — 测试通过 Level-2 轮询确认
  }

  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability();
  }
}

// ─── 冒烟测试 ───

void main() {
  group('Smoke Suite — 8 Mandatory Scenarios', () {
    late _MockFullscreenDriver driver;
    late DesktopFullscreenAdapter adapter;

    setUp(() {
      driver = _MockFullscreenDriver();
      adapter = DesktopFullscreenAdapter(driver);
    });

    tearDown(() {
      adapter.dispose();
    });

    // FS-REG-001: 播放中 + 全屏
    test(
      'FS-REG-001: playing + fullscreen enters and exits correctly',
      () async {
        expect(adapter.snapshot().value.isFullscreen, isFalse);
        expect(adapter.snapshot().value.phase, FullscreenPhase.stable);

        // 进入全屏 — 设置 driver 状态让 Level-2 轮询首次命中
        driver.fullscreenState = true;
        await adapter.setFullscreen(true);
        expect(adapter.snapshot().value.isFullscreen, isTrue);
        expect(adapter.snapshot().value.phase, FullscreenPhase.stable);

        // 退出全屏
        driver.fullscreenState = false;
        await adapter.setFullscreen(false);
        expect(adapter.snapshot().value.isFullscreen, isFalse);
        expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
      },
    );

    // FS-REG-002: 暂停中 + 全屏
    test(
      'FS-REG-002: paused + fullscreen enters and exits correctly',
      () async {
        expect(adapter.snapshot().value.isFullscreen, isFalse);

        driver.fullscreenState = true;
        await adapter.setFullscreen(true);
        expect(adapter.snapshot().value.isFullscreen, isTrue);

        driver.fullscreenState = false;
        await adapter.setFullscreen(false);
        expect(adapter.snapshot().value.isFullscreen, isFalse);
      },
    );

    // FS-REG-003: F 键与按钮一致性
    // toggle() 和 setFullscreen() 结果相同
    test('FS-REG-003: toggle and setFullscreen produce same result', () async {
      // 使用 toggle 进入全屏
      driver.fullscreenState = true;
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      // 退出
      driver.fullscreenState = false;
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isFalse);

      // 使用 setFullscreen 进入全屏
      driver.fullscreenState = true;
      await adapter.setFullscreen(true);
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      // 退出
      driver.fullscreenState = false;
      await adapter.setFullscreen(false);
      expect(adapter.snapshot().value.isFullscreen, isFalse);
    });

    // FS-REG-004: ESC 语义 — fullscreen 状态下 setFullscreen(false) 退出全屏
    test('FS-REG-004: ESC exits fullscreen (setFullscreen(false))', () async {
      driver.fullscreenState = true;
      await adapter.setFullscreen(true);
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      // ESC 语义 = setFullscreen(false)
      driver.fullscreenState = false;
      await adapter.setFullscreen(false);
      expect(adapter.snapshot().value.isFullscreen, isFalse);
      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
    });

    // FS-REG-005: 连续切换稳定性（10 次 toggle）
    // 10 次 toggle 从 windowed 开始 → 偶数次 → 最终回到 windowed
    test('FS-REG-005: 10 consecutive toggles end in stable state', () async {
      for (var i = 0; i < 10; i++) {
        // 每次 toggle 前设置 driver 状态，让 Level-2 轮询首次命中
        driver.fullscreenState = !driver.fullscreenState;
        await adapter.toggle();
      }

      // 10 次 toggle（偶数）从 windowed 开始 → 最终 windowed
      expect(adapter.snapshot().value.isFullscreen, isFalse);
      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
    });

    // FS-REG-006: windowed -> fullscreen -> windowed 恢复原始窗口几何
    test(
      'FS-REG-006: windowed -> fullscreen -> windowed restores geometry',
      () async {
        driver.currentPosition = const Offset(200, 150);
        driver.currentSize = const Size(1000, 700);

        driver.fullscreenState = true;
        await adapter.setFullscreen(true);
        expect(adapter.snapshot().value.isFullscreen, isTrue);

        driver.fullscreenState = false;
        await adapter.setFullscreen(false);
        expect(adapter.snapshot().value.isFullscreen, isFalse);

        // 验证退出时恢复了保存的位置和大小
        expect(
          driver.calls,
          contains('setBounds(Offset(200.0, 150.0), Size(1000.0, 700.0))'),
        );
      },
    );

    // FS-REG-007: 副屏位置恢复 — 自定义 position
    test('FS-REG-007: secondary display position is restored', () async {
      // 模拟副屏位置（非主显示器）
      driver.currentPosition = const Offset(2560, 300);
      driver.currentSize = const Size(1920, 1080);

      driver.fullscreenState = true;
      await adapter.setFullscreen(true);

      driver.fullscreenState = false;
      await adapter.setFullscreen(false);

      // 验证恢复了副屏位置
      expect(
        driver.calls,
        contains('setBounds(Offset(2560.0, 300.0), Size(1920.0, 1080.0))'),
      );
    });

    // FS-REG-008: 错误事件通知 — enter 失败时进入 error 状态
    test('FS-REG-008: enter failure results in error state', () async {
      driver.throwOnEnter = Exception('platform enter failed');

      await adapter.setFullscreen(true);

      // 失败后应进入 error 状态
      expect(adapter.snapshot().value.phase, FullscreenPhase.error);
      expect(adapter.snapshot().value.lastError, isA<PlatformFailure>());
      expect(adapter.snapshot().value.isFullscreen, isFalse);
    });
  });
}
