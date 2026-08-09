import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// 控制栏状态桥测试 — [PlayerControlsState] 订阅 [PlayerPort] stream 转写为
/// ValueNotifier；seek/倍速保留直达 port，音量/静音写走 engine。
///
/// 基础播放命令已统一由 PlayerActions → PlaybackController 负责，因此此处只锁定
/// media_kit Player stream 仍是播放图标和进度显示的数据源。
void main() {
  late FakeEngine engine;
  late FakePlayerControls port;
  late PlayerControlsState state;

  setUp(() {
    engine = FakeEngine();
    port = FakePlayerControls();
    state = PlayerControlsState(port, engine: engine);
    state.init();
  });

  tearDown(() {
    state.dispose();
    port.dispose();
    engine.dispose();
  });

  // 1. init 从 port 快照初始化 isPlaying 与 volume01
  test('init 从 port 快照初始化 isPlaying 与 volume01', () {
    // 默认 FakePlayerControls: isPlayingNow=false, volumeNow=100 → volume01=1.0
    expect(state.isPlaying.value, false);
    expect(state.volume01.value, 1.0);
  });

  // 2. seek 乐观更新 positionMs 再调 port.seek — 让 seek-hold 立即到达容差
  test('seek 乐观更新 positionMs 再调 port.seek', () {
    state.durationMs.value = 60000;
    state.seek(5000);
    expect(port.lastSeekPosition, const Duration(milliseconds: 5000));
    expect(state.positionMs.value, 5000); // 乐观更新立即生效,不等 stream
  });

  // 4. setVolume 写走 engine(保 _preMuteVolume 语义),不写 port
  test('setVolume 写走 engine,不写 port', () {
    state.setVolume(0.5);
    expect(engine.setVolumeCallCount, 1);
    expect(engine.lastSetVolumeValue, 0.5);
  });

  // 5. setRate 直写 port
  test('setRate 直写 port', () {
    state.setRate(2.0);
    expect(port.setRateCallCount, 1);
    expect(port.lastRate, 2.0);
  });

  // 6. stream.playing 推送 → isPlaying 更新(驱动播放/暂停图标)
  test('stream.playing 推送 → isPlaying 更新(驱动图标)', () async {
    port.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);
    expect(state.isPlaying.value, true);
  });

  // 7. stream.position 推送 → positionMs 更新(驱动进度条)
  test('stream.position 推送 → positionMs 更新(驱动进度)', () async {
    port.emitPosition(const Duration(milliseconds: 3000));
    await Future<void>.delayed(Duration.zero);
    expect(state.positionMs.value, 3000);
  });

  // 8. stream.volume(0-100) 推送 → volume01(0-1) 转换
  test('stream.volume(0-100) 推送 → volume01(0-1) 转换', () async {
    port.emitVolume(75.0);
    await Future<void>.delayed(Duration.zero);
    expect(state.volume01.value, closeTo(0.75, 1e-9));
  });

  group('PlayerVideoControls 生产装配', () {
    late FakeEngine widgetEngine;
    late FakeVideoControlsPort video;
    late ValueNotifier<String> currentFileName;
    late ValueNotifier<bool> openFileEnabled;

    setUp(() {
      widgetEngine = FakeEngine();
      video = FakeVideoControlsPort();
      currentFileName = ValueNotifier<String>('movie.mp4');
      openFileEnabled = ValueNotifier<bool>(true);
    });

    tearDown(() {
      currentFileName.dispose();
      openFileEnabled.dispose();
      video.dispose();
      widgetEngine.dispose();
    });

    Future<void> pumpControls(
      WidgetTester tester, {
      required PlayerActions actions,
      FakeVideoControlsPort? controlsPort,
      ValueListenable<bool>? resizing,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                video: controlsPort ?? video,
                engine: widgetEngine,
                actions: actions,
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
                resizing: resizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('替换 currentFileName 后只响应新 notifier', (tester) async {
      final oldFileName = currentFileName;
      await pumpControls(tester, actions: const PlayerActions());
      expect(find.text('movie.mp4'), findsOneWidget);

      final replacement = ValueNotifier<String>('replacement.mp4');
      currentFileName = replacement;
      await pumpControls(tester, actions: const PlayerActions());
      expect(find.text('replacement.mp4'), findsOneWidget);
      expect(find.text('movie.mp4'), findsNothing);

      // 旧源已从合并监听器解绑；更新它不应安排新帧，而不是仅仅保持当前标题。
      expect(tester.binding.hasScheduledFrame, isFalse);
      oldFileName.value = 'stale.mp4';
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump();
      expect(find.text('replacement.mp4'), findsOneWidget);
      expect(find.text('stale.mp4'), findsNothing);

      // 新源仍然有效，后续更新必须安排新帧并驱动标题更新。
      replacement.value = 'latest.mp4';
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(find.text('latest.mp4'), findsOneWidget);

      // 先卸载仍订阅 replacement 的控件树，再释放 notifier，避免
      // ListenableBuilder 在 dispose 时从已释放源移除监听器。
      await tester.pumpWidget(const SizedBox.shrink());
      replacement.dispose();
      currentFileName = oldFileName;
    });

    testWidgets('四个基础按钮只命中 PlayerActions', (tester) async {
      var playPauseCount = 0;
      var stopCount = 0;
      final seekBackValues = <int>[];
      final seekForwardValues = <int>[];
      final actions = PlayerActions(
        onPlayPause: () => playPauseCount++,
        onSeekBack: seekBackValues.add,
        onSeekForward: seekForwardValues.add,
        onStop: () => stopCount++,
      );

      await pumpControls(tester, actions: actions);

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(seekBackValues, [Tokens.skipShortMs]);
      expect(playPauseCount, 1);
      expect(seekForwardValues, [Tokens.skipLongMs]);
      expect(stopCount, 1);
      expect(widgetEngine.togglePlayPauseCallCount, 0);
      expect(widgetEngine.skipBackCallCount, 0);
      expect(widgetEngine.skipForwardCallCount, 0);
    });

    testWidgets('Space Left Right 与按钮复用同一动作入口', (tester) async {
      var playPauseCount = 0;
      final seekBackValues = <int>[];
      final seekForwardValues = <int>[];
      final actions = PlayerActions(
        onPlayPause: () => playPauseCount++,
        onSeekBack: seekBackValues.add,
        onSeekForward: seekForwardValues.add,
      );

      await pumpControls(tester, actions: actions);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(playPauseCount, 1);
      expect(seekBackValues, [Tokens.skipShortMs]);
      expect(seekForwardValues, [Tokens.skipLongMs]);
      expect(widgetEngine.togglePlayPauseCallCount, 0);
      expect(widgetEngine.skipBackCallCount, 0);
      expect(widgetEngine.skipForwardCallCount, 0);
    });

    testWidgets('F 使用当前 route 端口切换 media_kit 全屏', (tester) async {
      var fullscreenSyncCount = 0;
      final actions = PlayerActions(
        onToggleFullscreen: () => fullscreenSyncCount++,
      );

      await pumpControls(tester, actions: actions);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);

      expect(fullscreenSyncCount, 1);
      expect(video.toggleFullscreenCallCount, 1);
      expect(video.exitFullscreenCallCount, 0);
    });

    testWidgets('ESC 只退出当前 fullscreen route 端口', (tester) async {
      video.isFullscreen = true;
      var fullscreenSyncCount = 0;
      final actions = PlayerActions(
        onToggleFullscreen: () => fullscreenSyncCount++,
      );

      await pumpControls(tester, actions: actions);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(fullscreenSyncCount, 1);
      expect(video.exitFullscreenCallCount, 1);
      expect(video.toggleFullscreenCallCount, 0);
    });

    testWidgets('窗口态 ESC 不触发全屏 route 操作', (tester) async {
      var fullscreenSyncCount = 0;
      final actions = PlayerActions(
        onToggleFullscreen: () => fullscreenSyncCount++,
      );

      await pumpControls(tester, actions: actions);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(fullscreenSyncCount, 0);
      expect(video.exitFullscreenCallCount, 0);
      expect(video.toggleFullscreenCallCount, 0);
    });

    testWidgets('auto-hide 后 resize 保持控件隐藏且不暴露活跃语义', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final resizing = ValueNotifier<bool>(false);
      final playingPort = FakePlayerControls(isPlayingNow: true);
      final playingVideo = FakeVideoControlsPort(player: playingPort);
      addTearDown(resizing.dispose);
      addTearDown(playingVideo.dispose);

      try {
        await pumpControls(
          tester,
          controlsPort: playingVideo,
          resizing: resizing,
          actions: const PlayerActions(),
        );

        final visibilityFinder = find.byKey(
          const Key('player-controls-visibility'),
        );
        final initialVisibilityElement = tester.element(visibilityFinder);

        // 先完成 playing 状态的自动隐藏，建立 resize 开始前的真实 UI 状态。
        await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
        await tester.pump(
          const Duration(milliseconds: Tokens.durationControlsFade + 1),
        );
        expect(tester.widget<Visibility>(visibilityFinder).visible, isFalse);
        expect(find.bySemanticsLabel('Play'), findsNothing);

        // resize 只能冻结隐藏策略和改变绘制状态，不能重挂载控制栏可见性节点，
        // 也不能让视觉上隐藏的按钮重新进入活跃 semantics 遍历。
        resizing.value = true;
        await tester.pump();
        await tester.pump(
          const Duration(milliseconds: Tokens.durationControlsFade + 1),
        );
        expect(tester.widget<Visibility>(visibilityFinder).visible, isFalse);
        expect(
          tester.element(visibilityFinder),
          same(initialVisibilityElement),
        );
        expect(find.bySemanticsLabel('Play'), findsNothing);

        resizing.value = false;
        await tester.pump();
        expect(tester.widget<Visibility>(visibilityFinder).visible, isFalse);
        expect(
          tester.element(visibilityFinder),
          same(initialVisibilityElement),
        );
        expect(find.bySemanticsLabel('Play'), findsNothing);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('暂停发生在自动淡出中仍恢复控制栏与 backdrop filter', (tester) async {
      final playingPort = FakePlayerControls(isPlayingNow: true);
      final playingVideo = FakeVideoControlsPort(player: playingPort);
      addTearDown(playingVideo.dispose);

      await pumpControls(
        tester,
        controlsPort: playingVideo,
        actions: const PlayerActions(),
      );

      final visibilityFinder = find.byKey(
        const Key('player-controls-visibility'),
      );
      final backdropFinder = find.byType(BackdropFilter, skipOffstage: false);
      expect(backdropFinder, findsOneWidget);
      final initialElement = tester.element(backdropFinder);

      // 先让 hide timer 到期；timer 回调只启动 reverse，再推进半个淡出
      // 周期以确认暂停发生在动画中段，而不是动画完成后。
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade ~/ 2),
      );
      expect(tester.widget<Visibility>(visibilityFinder).visible, isTrue);
      // opacity 仍高于 0.01 阈值，中段淡出不会提前关闭背景采样。
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

      // 暂停必须反转尚未结束的 reverse animation，不能让其随后进入
      // dismissed 并隐藏控件。
      playingPort.emitPlaying(false);
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );

      expect(tester.widget<Visibility>(visibilityFinder).visible, isTrue);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);
      expect(tester.element(backdropFinder), same(initialElement));
    });

    testWidgets('auto-hide 淡出停用保留的控制栏 backdrop filter', (tester) async {
      final playingPort = FakePlayerControls(isPlayingNow: true);
      final playingVideo = FakeVideoControlsPort(player: playingPort);
      addTearDown(playingVideo.dispose);

      await pumpControls(
        tester,
        controlsPort: playingVideo,
        actions: const PlayerActions(),
      );

      // 控制栏淡出期间必须及早停止背景采样，但不能替换 Windows AX
      // 依赖的滤镜祖先链。
      final backdropFinder = find.byType(BackdropFilter, skipOffstage: false);
      expect(backdropFinder, findsOneWidget);
      final initialElement = tester.element(backdropFinder);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );

      expect(backdropFinder, findsOneWidget);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
      expect(tester.element(backdropFinder), same(initialElement));

      // FakePlayerControls 的 broadcast stream 异步投递；第一帧先让
      // PlayerControlsState → AutoHideController.show() 进入可见态。此时淡入
      // 动画尚未跨过 ControlBar 的 0.01 blur 阈值，滤镜必须仍保持关闭。
      playingPort.emitPlaying(false);
      await tester.pump();

      final visibilityFinder = find.byKey(
        const Key('player-controls-visibility'),
      );
      expect(tester.widget<Visibility>(visibilityFinder).visible, isTrue);
      expect(backdropFinder, findsOneWidget);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
      expect(tester.element(backdropFinder), same(initialElement));

      // 先消费 forward() 调度的首个零 elapsed ticker frame；否则下一次带时长的
      // pump 可能只用于建立动画起点，尚未推进 opacity。
      await tester.pump();

      // 推进 show() 的淡入动画；opacity 跨过阈值后才恢复实时背景采样。
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );

      expect(backdropFinder, findsOneWidget);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);
      expect(tester.element(backdropFinder), same(initialElement));
    });

    testWidgets('resize 立即停用并在 non-idle 状态恢复控制栏 backdrop filter', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(false);
      addTearDown(resizing.dispose);
      // 使用非 idle 的 engine，锁定正常媒体态完成 resize 后恢复 blur 的契约。
      widgetEngine.play();

      await pumpControls(
        tester,
        resizing: resizing,
        actions: const PlayerActions(),
      );

      final controlBarFinder = find.byType(ControlBar);
      final backdropFinder = find.descendant(
        of: controlBarFinder,
        matching: find.byType(BackdropFilter),
      );
      expect(backdropFinder, findsOneWidget);
      final initialElement = tester.element(backdropFinder);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

      // resize 上升沿必须直接停用实时背景采样，不能等待 decoration 的淡出动画。
      resizing.value = true;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
      expect(tester.element(backdropFinder), same(initialElement));

      resizing.value = false;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);
      expect(tester.element(backdropFinder), same(initialElement));
    });

    testWidgets('playing stream 驱动自动隐藏且暂停后恢复常显', (tester) async {
      final playingPort = FakePlayerControls(isPlayingNow: true);
      final playingVideo = FakeVideoControlsPort(player: playingPort);
      addTearDown(playingVideo.dispose);

      await pumpControls(
        tester,
        controlsPort: playingVideo,
        actions: const PlayerActions(),
      );

      Visibility controlsVisibility() => tester.widget<Visibility>(
        find.byKey(const Key('player-controls-visibility')),
      );

      expect(controlsVisibility().visible, isTrue);
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );
      expect(controlsVisibility().visible, isFalse);

      playingPort.emitPlaying(false);
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );
      expect(controlsVisibility().visible, isTrue);

      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed + 1));
      expect(controlsVisibility().visible, isTrue);
    });
  });
}
