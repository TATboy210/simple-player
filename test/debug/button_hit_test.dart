/// R1 调试测试 — 验证控制栏按钮是否可点击
///
/// 运行: flutter test test/debug/button_hit_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import '../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;
  // 路径B Commit1:ControlBar 新签名需 ControlBarViewModel(从 engine 派生).
  // isFullscreen 共享 notifier(hit 测试不需全屏交互),setUp/tearDown 管理生命周期.
  late ValueNotifier<bool> isFullscreen;

  setUp(() {
    // 匹配生产环境:app 启动时调 KernelLoggerImpl.init()。测试中 transitionTo
    // 非法转换会触发 KernelLoggerImpl.I.warn,未 init 时抛 StateError(如 idle→idle)。
    KernelLoggerImpl.init();
    engine = FakeEngine();
    engine.state.value = MediaState.playing;
    engine.duration.value = 60000;
    engine.position.value = 10000;
    isFullscreen = ValueNotifier<bool>(false);
  });

  tearDown(() {
    engine.dispose();
    isFullscreen.dispose();
  });

  /// 从 FakeEngine 派生 ControlBarViewModel，供当前 ControlBar 测试使用。
  ControlBarViewModel buildVm(FakeEngine e) => ControlBarViewModel(
    isPlaying: e.isPlayingNotifier,
    position: e.position,
    duration: e.duration,
    volume: e.volume,
    isMuted: e.isMuted,
    rate: e.playbackSpeed,
    isFullscreen: isFullscreen,
    onSeek: e.seekTo,
    onPlayPause: e.togglePlayPause,
    onSeekBack: e.skipBack,
    onSeekForward: e.skipForward,
    onToggleMute: () => e.setMute(!e.isMuted.value),
    onSetVolume: e.setVolume,
    onSetRate: e.setPlaybackRate,
  );

  Widget buildControlBarOnly({PlayerActions? actions, bool isIdle = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: ControlBar(
            vm: buildVm(engine),
            isIdle: isIdle,
            // onStop 显式传 engine.stop — 新签名 CenterGroup 移除 engine.stop
            // fallback(actions.onStop null 时禁用)。显式传保 stop 按钮可点,
            // 等价旧签名 fallback 行为(idle 态 stop 路由到 engine).
            actions: actions ?? PlayerActions(onStop: engine.stop),
          ),
        ),
      ),
    );
  }

  group('R1 Debug: Button hit test', () {
    testWidgets('ControlBar only — play/pause button tappable', (tester) async {
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      final playButton = find.byIcon(Icons.pause);
      expect(playButton, findsOneWidget, reason: 'Should find pause icon');

      await tester.tap(playButton);
      await tester.pump();

      expect(
        engine.state.value,
        MediaState.paused,
        reason: 'togglePlayPause should change state to paused',
      );
    });

    testWidgets('idle state routes stop and play taps to the engine', (
      tester,
    ) async {
      // RED: CenterGroup currently disables every button when isIdle is true.
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildControlBarOnly(isIdle: true));
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.stop));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.stopCallCount, 1);
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('opening state keeps play button interactive', (tester) async {
      // RED contract: opening must route input to the idempotent engine, not no-op.
      engine.state.value = MediaState.opening;
      await tester.pumpWidget(buildControlBarOnly(isIdle: true));
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('replay 10 requests a 10000ms backward skip', (tester) async {
      // RED: current CenterGroup passes a seconds token (10) as milliseconds.
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();

      // Assert
      expect(engine.skipBackCallCount, 1);
      expect(engine.lastSkipBackMs, 10000);
    });

    testWidgets('forward 30 requests a 30000ms forward skip', (tester) async {
      // RED: current CenterGroup passes a seconds token (30) as milliseconds.
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pump();

      // Assert
      expect(engine.skipForwardCallCount, 1);
      expect(engine.lastSkipForwardMs, 30000);
    });

    testWidgets('seeking state routes two consecutive forward taps', (
      tester,
    ) async {
      // RED contract: a transient seek must not suppress the latest user intent.
      engine.isSeeking.value = true;
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pump();

      // Assert
      expect(engine.skipForwardCallCount, 2);
    });
  });
}
