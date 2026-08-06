import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
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
    late ValueNotifier<int> playlistGeneration;
    late ValueNotifier<bool> openFileEnabled;

    setUp(() {
      widgetEngine = FakeEngine();
      video = FakeVideoControlsPort();
      currentFileName = ValueNotifier<String>('movie.mp4');
      playlistGeneration = ValueNotifier<int>(0);
      openFileEnabled = ValueNotifier<bool>(true);
    });

    tearDown(() {
      currentFileName.dispose();
      playlistGeneration.dispose();
      openFileEnabled.dispose();
      video.dispose();
      widgetEngine.dispose();
    });

    Future<void> pumpControls(
      WidgetTester tester, {
      required PlayerActions actions,
      FakeVideoControlsPort? controlsPort,
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
                playlist: Playlist(),
                playlistGeneration: playlistGeneration,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('六个基础按钮只命中 PlayerActions', (tester) async {
      var playPauseCount = 0;
      var previousCount = 0;
      var nextCount = 0;
      var stopCount = 0;
      final seekBackValues = <int>[];
      final seekForwardValues = <int>[];
      final actions = PlayerActions(
        onPlayPause: () => playPauseCount++,
        onSeekBack: seekBackValues.add,
        onSeekForward: seekForwardValues.add,
        onPrevious: () => previousCount++,
        onNext: () => nextCount++,
        onStop: () => stopCount++,
      );

      await pumpControls(tester, actions: actions);

      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(previousCount, 1);
      expect(seekBackValues, [Tokens.skipShortMs]);
      expect(playPauseCount, 1);
      expect(seekForwardValues, [Tokens.skipLongMs]);
      expect(nextCount, 1);
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
