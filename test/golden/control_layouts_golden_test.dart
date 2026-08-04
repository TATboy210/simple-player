import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';

import '../helpers/fake_engine.dart';
import 'golden_comparator.dart';

void main() {
  setUp(() => enableTolerantGoldens());

  late FakeEngine engine;
  // 渐进路径:ControlBar 需 playlist + playlistGeneration(required)。
  late Playlist playlist;
  late ValueNotifier<int> playlistGeneration;
  // 路径B Commit1:ControlBar 新签名需 ControlBarViewModel(从 engine 派生).
  // isFullscreen 共享 notifier(golden 测试无全屏交互),setUp/tearDown 管理.
  late ValueNotifier<bool> isFullscreen;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    playlistGeneration = ValueNotifier<int>(0);
    isFullscreen = ValueNotifier<bool>(false);
  });

  tearDown(() {
    engine.dispose();
    playlistGeneration.dispose();
    isFullscreen.dispose();
  });

  /// 从 FakeEngine 派生 ControlBarViewModel — 数据源仍 engine(同 controls_overlay).
  /// golden 渲染输出不变(纯签名改造),无需 --update-goldens.
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

  Widget buildControlSubject({
    required Widget child,
    double width = 800,
    double height = 200,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  group('ControlBar golden', () {
    testWidgets('idle state', (tester) async {
      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            vm: buildVm(engine),
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            isIdle: true,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_idle.png'),
      );
    });

    testWidgets('playing state', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 15000;
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            vm: buildVm(engine),
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_playing.png'),
      );
    });

    testWidgets('fullscreen state', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 30000;
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            vm: buildVm(engine),
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_fullscreen.png'),
      );
    });
  });

  group('ProgressBar golden', () {
    testWidgets('empty (no duration)', (tester) async {
      await tester.pumpWidget(
        buildControlSubject(height: 60, child: ProgressBar(position: engine.position, duration: engine.duration, onSeek: engine.seekTo)),
      );
      await expectLater(
        find.byType(ProgressBar),
        matchesGoldenFile('goldens/progress_bar_empty.png'),
      );
    });

    testWidgets('half progress', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 30000;

      await tester.pumpWidget(
        buildControlSubject(height: 60, child: ProgressBar(position: engine.position, duration: engine.duration, onSeek: engine.seekTo)),
      );
      await expectLater(
        find.byType(ProgressBar),
        matchesGoldenFile('goldens/progress_bar_half.png'),
      );
    });
  });

  group('VolumeControls golden', () {
    testWidgets('full volume', (tester) async {
      engine.configureMedia();
      engine.volume.value = 1.0;
      engine.isMuted.value = false;

      await tester.pumpWidget(
        buildControlSubject(
          width: 200,
          height: 60,
          child: VolumeButton(volume: engine.volume, isMuted: engine.isMuted, onToggleMute: () => engine.setMute(!engine.isMuted.value), onSetVolume: engine.setVolume),
        ),
      );
      await expectLater(
        find.byType(VolumeButton),
        matchesGoldenFile('goldens/volume_controls_full.png'),
      );
    });

    testWidgets('muted', (tester) async {
      engine.configureMedia();
      engine.isMuted.value = true;

      await tester.pumpWidget(
        buildControlSubject(
          width: 200,
          height: 60,
          child: VolumeButton(volume: engine.volume, isMuted: engine.isMuted, onToggleMute: () => engine.setMute(!engine.isMuted.value), onSetVolume: engine.setVolume),
        ),
      );
      await expectLater(
        find.byType(VolumeButton),
        matchesGoldenFile('goldens/volume_controls_muted.png'),
      );
    });
  });
}
