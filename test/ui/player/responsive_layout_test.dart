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
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';
import '../../helpers/fake_window_service.dart';
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
  // 路径B Commit1:ControlBar 新签名需 ControlBarViewModel(从 engine 派生).
  late ValueNotifier<bool> isFullscreen;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    isFullscreen = ValueNotifier<bool>(false);
  });

  tearDown(() {
    engine.dispose();
    isFullscreen.dispose();
  });

  /// 从 FakeEngine 派生 ControlBarViewModel，供响应式布局测试使用。
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
          ControlBar(vm: buildVm(engine), actions: const PlayerActions()),
          width: 800,
          height: 200,
        ),
      );
      await tester.pump();

      // CenterGroup always visible
      expect(find.byType(CenterGroup), findsOneWidget);
      // 单文件播放器不再展示播放模式或队列入口。
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.byIcon(Icons.queue_music), findsNothing);
    });

    testWidgets('keeps the blur element attached when opacity reaches zero', (
      tester,
    ) async {
      final opacity = AnimationController(vsync: tester, value: 1);
      addTearDown(opacity.dispose);

      await tester.pumpWidget(
        _wrapWithApp(
          ControlBar(
            vm: buildVm(engine),
            actions: const PlayerActions(),
            opacity: opacity,
          ),
          width: 800,
          height: 200,
        ),
      );
      await tester.pump();

      final initialBlurElement = tester.element(find.byType(BackdropFilter));

      // resize 淡出只应停用滤镜，不能替换语义内容的中间祖先拓扑。
      opacity.value = 0;
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.element(find.byType(BackdropFilter)),
        same(initialBlurElement),
      );
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

    testWidgets('keeps the panel inside a narrow window after its animation', (
      tester,
    ) async {
      const windowWidth = 300.0;
      const windowHeight = 260.0;
      await tester.pumpWidget(
        _wrapWithApp(
          PlaylistPanel(
            playlist: playlist,
            visible: true,
            onClose: () {},
            onSelectIndex: (_) {},
            onRemoveIndex: (_) {},
            availableWidth: windowWidth,
          ),
          width: windowWidth,
          height: windowHeight,
        ),
      );
      await tester.pumpAndSettle();

      final window = tester.getRect(find.byType(PlaylistPanel));
      final panel = tester.getRect(
        find.byKey(const ValueKey('playlist-panel-surface')),
      );
      expect(panel.left, greaterThanOrEqualTo(window.left));
      expect(panel.right, lessThanOrEqualTo(window.right));
      expect(panel.top, greaterThanOrEqualTo(window.top));
      expect(panel.bottom, lessThanOrEqualTo(window.bottom));
    });
  });

  group('CustomTitleBar responsive sizing', () {
    late FakeWindowService windowService;

    setUp(() {
      windowService = FakeWindowService();
    });

    tearDown(() {
      windowService.dispose();
    });

    testWidgets(
      'keeps window controls visible without a flex overflow at 120px',
      (tester) async {
        final reportedErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = reportedErrors.add;
        addTearDown(() => FlutterError.onError = previousOnError);

        await tester.pumpWidget(
          _wrapWithApp(
            CustomTitleBar(windowService: windowService),
            width: 120,
            height: Tokens.titleBarHeight,
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('titlebar-minimize')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('titlebar-maximize-toggle')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('titlebar-close')), findsOneWidget);
        FlutterError.onError = previousOnError;
        expect(
          reportedErrors.where(
            (details) => details.exceptionAsString().contains('overflowed'),
          ),
          isEmpty,
        );
      },
    );
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
