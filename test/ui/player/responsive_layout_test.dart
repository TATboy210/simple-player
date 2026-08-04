import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import '../../helpers/fake_engine.dart';

Widget _wrapWithApp(Widget child, {double width = 800, double height = 600}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  );
}

void main() {
  late FakeEngine engine;
  late Playlist playlist;
  // 渐进路径:ControlBar 需 playlistGeneration(required) —
  // playMode 下沉到 LeftButtonGroup 内部读 playlist.mode,generation 驱动重建。
  late ValueNotifier<int> playlistGeneration;
  // 路径B Commit1:ControlBar 新签名需 ControlBarViewModel(从 engine 派生).
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

  group('ControlBar button groups', () {
    testWidgets('wide layout shows all three groups', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          ControlBar(
            vm: buildVm(engine),
            actions: const PlayerActions(),
            playlist: playlist,
            playlistGeneration: playlistGeneration,
          ),
          width: 800,
          height: 200,
        ),
      );
      await tester.pump();

      // CenterGroup always visible
      expect(find.byType(CenterGroup), findsOneWidget);
      // Play mode button (left group) visible
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });
  });

  group('PlaylistPanel responsive sizing', () {
    testWidgets('renders with normal dimensions', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          PlaylistPanel(
            playlist: playlist,
            visible: true,
            onClose: () {},
            onSelectIndex: (_) {},
            onRemoveIndex: (_) {},
            availableWidth: 800,
          ),
          width: 800,
          height: 600,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Panel uses standard dimensions
      expect(find.byType(PlaylistPanel), findsOneWidget);
    });
  });

  group('Tokens responsive constants', () {
    test('breakpointWide is 1200', () {
      expect(Tokens.breakpointWide, 1200);
    });

    test('breakpointUltraCompact is 360', () {
      expect(Tokens.breakpointUltraCompact, 360);
    });

    test('narrow playlist dimensions are smaller than normal', () {
      expect(
        Tokens.playlistPanelWidthNarrow,
        lessThan(Tokens.playlistPanelWidth),
      );
      expect(
        Tokens.playlistPanelHeightNarrow,
        lessThan(Tokens.playlistPanelHeight),
      );
    });

    test('compactBreakpoint unchanged at 500', () {
      expect(Tokens.compactBreakpoint, 500);
    });
  });
}
