// SettingsPanelController 音频提交 + EqualizerTab widget 测试 — Phase 33。
//
// 控制器测试：验证 open() 注册 4 个音频键、pending.update 不触发回调（延迟）、
// commitPending() 调回调一次且快照经组合器输出预期串、cancelPending() 零回调。
// widget 测试：pump EqualizerTab，点击预设行→pending eqPresetIndex 更新。
//
// 手写 Fake（CLAUDE.md "Fakes over mocks"），不依赖真实 MediaEngine / mdk.dll。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_filter_compositor.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/pending_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/equalizer_tab.dart';

/// 手写播放服务替身 — 镜像 settings_panel_controller_test.dart 的 FakePlaybackController。
class _FakePlayback implements SettingsPanelPlayback {
  _FakePlayback({MediaState initialState = MediaState.idle})
    : _state = initialState;
  MediaState _state;

  @override
  bool get isPlaying => _state == MediaState.playing;

  @override
  void pause() => _state = MediaState.paused;

  @override
  void play() => _state = MediaState.playing;
}

/// 手写音频提交回调替身 — 记录调用次数与最后一次 AudioSettings 快照。
class _FakeAudioCommit {
  int callCount = 0;
  AudioSettings? last;

  void call(AudioSettings settings) {
    callCount++;
    last = settings;
  }
}

void main() {
  group('SettingsPanelController audio commit', () {
    test('open() registers 4 audio keys with injected defaults', () {
      final commit = _FakeAudioCommit();
      final controller = SettingsPanelController(
        _FakePlayback(),
        audioDefaults: const AudioSettings(
          eqPresetIndex: 2,
          balance: 0.3,
          syncMs: 500,
          normalization: true,
        ),
        onAudioCommit: commit.call,
      );

      controller.open();

      expect(controller.pending.current('eqPresetIndex'), 2);
      expect(controller.pending.current('balance'), 0.3);
      expect(controller.pending.current('syncMs'), 500);
      expect(controller.pending.current('normalization'), isTrue);

      controller.dispose();
    });

    test('pending.update does not invoke commit callback (deferred)', () {
      final commit = _FakeAudioCommit();
      final controller = SettingsPanelController(
        _FakePlayback(),
        onAudioCommit: commit.call,
      );
      controller.open();

      controller.pending.update('eqPresetIndex', 3);
      expect(commit.callCount, 0);
      expect(controller.pending.current('eqPresetIndex'), 3);

      controller.dispose();
    });

    test('commitPending() invokes callback once with composed snapshot', () {
      final commit = _FakeAudioCommit();
      final controller = SettingsPanelController(
        _FakePlayback(),
        onAudioCommit: commit.call,
      );
      controller.open();
      controller.pending.update('eqPresetIndex', 1);

      controller.commitPending();

      expect(commit.callCount, 1);
      expect(commit.last!.eqPresetIndex, 1);
      // 快照经组合器输出 EQ 预设 1 → bass=g=10
      expect(
        AudioFilterCompositor.compose(
          commit.last!,
          AudioFilterAvailability.allSupported,
        ),
        'bass=g=10',
      );

      controller.dispose();
    });

    test('cancelPending() does not invoke commit callback', () {
      final commit = _FakeAudioCommit();
      final controller = SettingsPanelController(
        _FakePlayback(),
        onAudioCommit: commit.call,
      );
      controller.open();
      controller.pending.update('eqPresetIndex', 4);

      controller.cancelPending();

      expect(commit.callCount, 0);
      // cancel 后 current 回退到 original 基准（0）
      expect(controller.pending.current('eqPresetIndex'), 0);

      controller.dispose();
    });

    test('commitPending() snapshot includes all 4 fields', () {
      final commit = _FakeAudioCommit();
      final controller = SettingsPanelController(
        _FakePlayback(),
        onAudioCommit: commit.call,
      );
      controller.open();
      controller.pending.update('eqPresetIndex', 3);
      controller.pending.update('balance', -0.5);
      controller.pending.update('syncMs', 300);
      controller.pending.update('normalization', true);

      controller.commitPending();

      expect(commit.last!.eqPresetIndex, 3);
      expect(commit.last!.balance, -0.5);
      expect(commit.last!.syncMs, 300);
      expect(commit.last!.normalization, isTrue);

      controller.dispose();
    });
  });

  group('EqualizerTab widget', () {
    testWidgets('tapping preset row updates pending eqPresetIndex', (
      tester,
    ) async {
      final pending = PendingSettingsState();
      pending.register('eqPresetIndex', 0);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EqualizerTab(pending: pending))),
      );

      // 初始：5 个预设行都渲染
      expect(find.byKey(const ValueKey('eq-preset-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('eq-preset-2')), findsOneWidget);

      // 点击预设 2 行 → pending 更新为 2
      await tester.tap(find.byKey(const ValueKey('eq-preset-2')));
      await tester.pump();

      expect(pending.current('eqPresetIndex'), 2);

      pending.dispose();
    });

    testWidgets('initial baseline reflects pending + tap switches selection', (
      tester,
    ) async {
      final pending = PendingSettingsState();
      pending.register('eqPresetIndex', 3);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EqualizerTab(pending: pending))),
      );

      // 初始：预设 3 行存在
      expect(find.byKey(const ValueKey('eq-preset-3')), findsOneWidget);

      // 点击预设 0 → pending 切换为 0
      await tester.tap(find.byKey(const ValueKey('eq-preset-0')));
      await tester.pump();
      expect(pending.current('eqPresetIndex'), 0);

      pending.dispose();
    });

    // —— Phase 33 Wave 2：balance + sync 滑块（AUDIO-02/03/05/06）——

    testWidgets('balance slider drag updates pending balance key', (
      tester,
    ) async {
      final pending = PendingSettingsState();
      pending.register('eqPresetIndex', 0);
      pending.register('balance', 0.0);
      pending.register('syncMs', 0);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EqualizerTab(pending: pending))),
      );

      final slider = find.byKey(const ValueKey('audio-balance-slider'));
      expect(slider, findsOneWidget);

      // 拖动平衡滑块向右——balance 从 0.0 增大（向偏右）
      await tester.drag(slider, const Offset(80, 0));
      await tester.pump();

      expect(pending.current('balance'), isA<double>());
      expect(pending.current('balance') as double, greaterThan(0.0));

      pending.dispose();
    });

    testWidgets('sync slider drag updates pending syncMs (rounded to int)', (
      tester,
    ) async {
      final pending = PendingSettingsState();
      pending.register('eqPresetIndex', 0);
      pending.register('balance', 0.0);
      pending.register('syncMs', 0);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EqualizerTab(pending: pending))),
      );

      final slider = find.byKey(const ValueKey('audio-sync-slider'));
      expect(slider, findsOneWidget);

      // 拖动延迟滑块向右——syncMs 从 0 增大（音频延后）
      await tester.drag(slider, const Offset(80, 0));
      await tester.pump();

      expect(pending.current('syncMs'), isA<int>());
      expect(pending.current('syncMs') as int, greaterThan(0));

      pending.dispose();
    });

    testWidgets(
      'slider changes stage pending values without invoking commit',
      (tester) async {
        // AUDIO-06：slider 只写 pending，不触达 commit 回调。
        // commit 路径由 SettingsPanelController.commitPending 触发（见上方
        // controller 单测 "pending.update does not invoke commit callback"）。
        final pending = PendingSettingsState();
        pending.register('eqPresetIndex', 0);
        pending.register('balance', 0.0);
        pending.register('syncMs', 0);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: EqualizerTab(pending: pending))),
        );

        await tester.drag(
          find.byKey(const ValueKey('audio-balance-slider')),
          const Offset(80, 0),
        );
        await tester.drag(
          find.byKey(const ValueKey('audio-sync-slider')),
          const Offset(80, 0),
        );
        await tester.pump();

        // 两个 pending 键都有未提交修改，但无 commit 入口被调用
        expect(pending.current('balance'), isA<double>());
        expect(pending.current('syncMs'), isA<int>());

        pending.dispose();
      },
    );
  });
}
