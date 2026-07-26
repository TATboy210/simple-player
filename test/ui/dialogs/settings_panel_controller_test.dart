// SettingsPanelController 单元测试 — 覆盖 PANEL-02。
//
// 使用手写 FakePlaybackController（implements SettingsPanelPlayback）替身，
// 不依赖真实 MediaEngine / mdk.dll，规避 headless FFI 加载失败风险
// （CLAUDE.md "Fakes over mocks"）。

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

/// 手写播放服务替身 — 记录 pause()/play() 调用次数，状态由 [MediaState] 驱动.
///
/// isPlaying 经窄接缝从 [_state] 派生（== MediaState.playing），使每个竞态
/// 场景显式可配置，无需扩展 SettingsPanelPlayback 或引入真实 MediaEngine
/// （CLAUDE.md "Fakes over mocks"）。
class FakePlaybackController implements SettingsPanelPlayback {
  FakePlaybackController({MediaState initialState = MediaState.idle})
    : _state = initialState;

  /// 当前播放状态 — pause/play 在此枚举上翻转，isPlaying 经 == 派生.
  MediaState _state;
  int pauseCallCount = 0;
  int playCallCount = 0;

  @override
  bool get isPlaying => _state == MediaState.playing;

  @override
  void pause() {
    pauseCallCount++;
    _state = MediaState.paused;
  }

  @override
  void play() {
    playCallCount++;
    _state = MediaState.playing;
  }
}

void main() {
  group('SettingsPanelController', () {
    test('open() while playing snapshots wasPlaying=true, pauses once, opens', () {
      // Arrange
      final fake = FakePlaybackController(initialState: MediaState.playing);
      final controller = SettingsPanelController(fake);

      // Act
      controller.open();

      // Assert
      expect(controller.state.isOpen.value, isTrue);
      expect(fake.pauseCallCount, 1);
      expect(fake.playCallCount, 0);

      controller.dispose();
    });

    test('open() while paused still pauses once (always-pause policy) and never resumes on close()', () {
      // Arrange
      final fake = FakePlaybackController(initialState: MediaState.paused);
      final controller = SettingsPanelController(fake);

      // Act
      controller.open();
      controller.close();

      // Assert — PAUSE-01: open() always pauses regardless of pre-open state;
      // non-playing snapshot means close() never resumes.
      expect(fake.pauseCallCount, 1);
      expect(fake.playCallCount, 0);

      controller.dispose();
    });

    test(
      'close() after opening while playing resumes once and resets dragOffset',
      () {
        // Arrange
        final fake = FakePlaybackController(initialState: MediaState.playing);
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
      final fake = FakePlaybackController(initialState: MediaState.playing);
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
      final fake = FakePlaybackController(initialState: MediaState.playing);
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
      final fake = FakePlaybackController(initialState: MediaState.playing);
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

    test(
      'PAUSE-04: opening snapshot → open → close issues pause once, no resume',
      () {
        // Arrange — 媒体正在打开（opening），非 playing 快照不可恢复
        final fake = FakePlaybackController(initialState: MediaState.opening);
        final controller = SettingsPanelController(fake);

        // Act
        controller.open();
        controller.close();

        // Assert — open() 总是暂停一次；close() 因快照非 playing 不恢复
        expect(fake.pauseCallCount, 1);
        expect(fake.playCallCount, 0);

        controller.dispose();
      },
    );

    test(
      'PAUSE-04: completed snapshot → open → close issues pause once, no resume',
      () {
        // Arrange — 媒体已播完（completed/EOF），非 playing 快照不可恢复
        final fake = FakePlaybackController(initialState: MediaState.completed);
        final controller = SettingsPanelController(fake);

        // Act
        controller.open();
        controller.close();

        // Assert
        expect(fake.pauseCallCount, 1);
        expect(fake.playCallCount, 0);

        controller.dispose();
      },
    );

    test(
      'PAUSE-04: manually paused snapshot → open → close issues pause once, no resume',
      () {
        // Arrange — 用户手动暂停（paused），非 playing 快照不可恢复
        final fake = FakePlaybackController(initialState: MediaState.paused);
        final controller = SettingsPanelController(fake);

        // Act
        controller.open();
        controller.close();

        // Assert
        expect(fake.pauseCallCount, 1);
        expect(fake.playCallCount, 0);

        controller.dispose();
      },
    );

    test(
      'PAUSE-04: playing snapshot → open → close issues pause once, resumes once',
      () {
        // Arrange — 媒体正在播放（playing），playing 快照可恢复
        final fake = FakePlaybackController(initialState: MediaState.playing);
        final controller = SettingsPanelController(fake);

        // Act
        controller.open();
        controller.close();

        // Assert — open() 暂停一次；close() 因 playing 快照恢复一次
        expect(fake.pauseCallCount, 1);
        expect(fake.playCallCount, 1);

        controller.dispose();
      },
    );
  });
}
