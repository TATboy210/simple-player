// SettingsPanelController 单元测试 — 覆盖 PANEL-02。
//
// 使用手写 FakePlaybackController（implements SettingsPanelPlayback）替身，
// 不依赖真实 MediaEngine / mdk.dll，规避 headless FFI 加载失败风险
// （CLAUDE.md "Fakes over mocks"）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

/// 手写播放服务替身 — 记录 pause()/play() 调用次数，支持配置初始播放状态。
class FakePlaybackController implements SettingsPanelPlayback {
  FakePlaybackController({bool initiallyPlaying = false})
    : _isPlaying = initiallyPlaying;

  bool _isPlaying;
  int pauseCallCount = 0;
  int playCallCount = 0;

  @override
  bool get isPlaying => _isPlaying;

  @override
  void pause() {
    pauseCallCount++;
    _isPlaying = false;
  }

  @override
  void play() {
    playCallCount++;
    _isPlaying = true;
  }
}

void main() {
  group('SettingsPanelController', () {
    test('open() while playing snapshots wasPlaying=true, pauses once, opens', () {
      // Arrange
      final fake = FakePlaybackController(initiallyPlaying: true);
      final controller = SettingsPanelController(fake);

      // Act
      controller.open();

      // Assert
      expect(controller.state.isOpen.value, isTrue);
      expect(fake.pauseCallCount, 1);
      expect(fake.playCallCount, 0);

      controller.dispose();
    });

    test('open() while paused never calls pause() and never resumes on close()', () {
      // Arrange
      final fake = FakePlaybackController(initiallyPlaying: false);
      final controller = SettingsPanelController(fake);

      // Act
      controller.open();
      controller.close();

      // Assert
      expect(fake.pauseCallCount, 0);
      expect(fake.playCallCount, 0);

      controller.dispose();
    });

    test(
      'close() after opening while playing resumes once and resets dragOffset',
      () {
        // Arrange
        final fake = FakePlaybackController(initiallyPlaying: true);
        final controller = SettingsPanelController(fake);
        controller.open();
        controller.state.dragOffset.value = const Offset(40, 20);

        // Act
        controller.close();

        // Assert
        expect(controller.state.isOpen.value, isFalse);
        expect(fake.playCallCount, 1);
        expect(controller.state.dragOffset.value, Offset.zero);

        controller.dispose();
      },
    );

    test('open() while already open is a no-op (idempotent)', () {
      // Arrange
      final fake = FakePlaybackController(initiallyPlaying: true);
      final controller = SettingsPanelController(fake);
      controller.open();
      expect(fake.pauseCallCount, 1);

      // Act — open again while already open
      controller.open();

      // Assert — no additional pause() call, isOpen still true
      expect(fake.pauseCallCount, 1);
      expect(controller.state.isOpen.value, isTrue);

      controller.dispose();
    });

    test('close() while already closed is a no-op (idempotent)', () {
      // Arrange
      final fake = FakePlaybackController(initiallyPlaying: true);
      final controller = SettingsPanelController(fake);
      // never opened

      // Act
      controller.close();

      // Assert — no play() call since it was never opened/paused
      expect(fake.playCallCount, 0);
      expect(controller.state.isOpen.value, isFalse);

      controller.dispose();
    });

    test('toggle() flips open/closed state with correct pause/play semantics', () {
      // Arrange
      final fake = FakePlaybackController(initiallyPlaying: true);
      final controller = SettingsPanelController(fake);

      // Act — toggle open
      controller.toggle();

      // Assert
      expect(controller.state.isOpen.value, isTrue);
      expect(fake.pauseCallCount, 1);

      // Act — toggle close
      controller.toggle();

      // Assert
      expect(controller.state.isOpen.value, isFalse);
      expect(fake.playCallCount, 1);

      controller.dispose();
    });
  });
}
