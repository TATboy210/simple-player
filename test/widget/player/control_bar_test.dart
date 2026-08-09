import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/player/time_range_display.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import '../../helpers/fake_engine.dart';

void _noop() {}

void main() {
  late FakeEngine engine;
  // 路径B Commit1:ControlBar 新签名需 ControlBarViewModel(从 engine 派生).
  // isFullscreen 用共享 notifier(测试不需全屏),避免每次 buildVm 创建泄漏.
  late ValueNotifier<bool> isFullscreen;

  /// 从 FakeEngine 派生 ControlBarViewModel，供 ControlBar 测试使用。
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

  setUp(() {
    engine = FakeEngine();
    isFullscreen = ValueNotifier<bool>(false);
  });

  tearDown(() {
    engine.dispose();
    isFullscreen.dispose();
  });

  Widget buildSubject({
    FakeEngine? eng,
    PlayerActions? actions,
    String? title,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: ControlBar(
            vm: buildVm(eng ?? engine),
            actions: actions ?? const PlayerActions(),
            title: title,
          ),
        ),
      ),
    );
  }

  group('ControlBar', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('renders TimeRangeDisplay', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(TimeRangeDisplay), findsOneWidget);
    });

    testWidgets('renders ProgressBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('places the time range to the right of the progress bar', (
      tester,
    ) async {
      // Arrange: 长标题确保 Row 1 不会为时间读数预留空间。
      await tester.pumpWidget(buildSubject(title: 'A very long media title'));
      await tester.pump();

      // Act: 取得两个时间导航元素的屏幕几何位置。
      final progressRect = tester.getRect(find.byType(ProgressBar));
      final timeRect = tester.getRect(find.byType(TimeRangeDisplay));

      // Assert: 第二行的时间读数固定在 seek 区域右侧且垂直对齐。
      expect(progressRect.right, lessThanOrEqualTo(timeRect.left));
      expect(progressRect.center.dy, closeTo(timeRect.center.dy, 0.1));
    });

    testWidgets('renders CenterGroup', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(CenterGroup), findsOneWidget);
    });

    testWidgets('shows secondary controls at width >= 500', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('shows all controls at narrow width (no breakpoint gating)', (
      tester,
    ) async {
      // CB-04: compact/ultra-compact breakpoints removed — always show full layout
      // Desktop player typical width 800+, use 600 to avoid Row overflow
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 600)),
            child: Scaffold(
              body: SizedBox(
                width: 600,
                height: 200,
                child: ControlBar(vm: buildVm(engine)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
      expect(tester.getSize(find.byType(ProgressBar)).width, greaterThan(0));
    });

    testWidgets('shows folder_open button when onOpenFile is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onOpenFile: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('hides folder_open button when onOpenFile is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsNothing);
    });

    testWidgets('shows fullscreen button when onToggleFullscreen is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onToggleFullscreen: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('shows subtitles button when onOpenSubtitle is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onOpenSubtitle: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.subtitles), findsOneWidget);
    });

    testWidgets('shows settings when onSettings is provided', (tester) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onSettings: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('ControlBar animation', () {
    Widget buildWithIdle({required bool isIdle}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: ControlBar(vm: buildVm(engine), isIdle: isIdle),
          ),
        ),
      );
    }

    testWidgets('renders Container with decoration', (tester) async {
      await tester.pumpWidget(buildWithIdle(isIdle: false));
      await tester.pump();

      // ControlBar uses Container + DecorationTween (not AnimatedContainer)
      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('idle state renders Container', (tester) async {
      await tester.pumpWidget(buildWithIdle(isIdle: true));
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('decoration animation parameter is accepted', (tester) async {
      // When decoration param is null, ControlBar uses _decorationPlaying directly
      await tester.pumpWidget(buildWithIdle(isIdle: true));
      await tester.pump();

      // Switch to playing — rebuild with new state
      await tester.pumpWidget(buildWithIdle(isIdle: false));
      await tester.pump();

      // ControlBar still renders correctly after state change
      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('ControlBar with decoration animation parameter', (
      tester,
    ) async {
      // When an external decoration animation is provided, ControlBar uses
      // DecorationTween to interpolate between idle and playing decorations
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 150),
        value: 1.0,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: ControlBar(
                vm: buildVm(engine),
                isIdle: false,
                decoration: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Container should render with the interpolated decoration
      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('ControlBar responsive layout', () {
    Widget buildWithWidth(double width) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 600)),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 200,
              child: ControlBar(vm: buildVm(engine)),
            ),
          ),
        ),
      );
    }

    testWidgets('narrow width still shows full layout', (tester) async {
      // CB-04: ultra-compact breakpoint removed — always show full layout
      // Use 600px to avoid Row overflow (desktop player minimum practical width)
      await tester.pumpWidget(buildWithWidth(600));
      await tester.pump();

      expect(find.byIcon(Icons.replay_10), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.forward_30), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);

      // Full CenterGroup (replay_10 + forward_30 always visible)
      expect(find.byType(CenterGroup), findsOneWidget);

      // Volume always visible (no breakpoint gating)
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('medium width shows full layout', (tester) async {
      // CB-04: compact breakpoint removed — always show full layout
      await tester.pumpWidget(buildWithWidth(700));
      await tester.pump();

      expect(find.byType(CenterGroup), findsOneWidget);
      expect(find.byIcon(Icons.replay_10), findsOneWidget);
      expect(find.byIcon(Icons.forward_30), findsOneWidget);

      // Volume always visible (no breakpoint gating)
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('full layout (w>500) shows all groups', (tester) async {
      await tester.pumpWidget(buildWithWidth(800));
      await tester.pump();

      // All controls visible
      expect(find.byType(CenterGroup), findsOneWidget);
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);

      // 单文件播放器不再展示播放模式或队列入口。
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.byIcon(Icons.queue_music), findsNothing);
    });

    testWidgets(
      '_buildBlur toggles filter for resize without replacing its element',
      (tester) async {
        final opacityController = AnimationController(vsync: tester, value: 1);
        final resizing = ValueNotifier(false);
        addTearDown(opacityController.dispose);
        addTearDown(resizing.dispose);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 200,
                child: ControlBar(
                  vm: buildVm(engine),
                  opacity: opacityController,
                  resizing: resizing,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final backdropFinder = find.byType(BackdropFilter);
        expect(backdropFinder, findsOneWidget);
        final initialElement = tester.element(backdropFinder);
        expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

        // resize 起始边沿应立即停用实时视频背景采样，而不是等待淡出结束。
        resizing.value = true;
        await tester.pump();
        expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
        expect(
          identical(tester.element(backdropFinder), initialElement),
          isTrue,
          reason: 'resize 期间只能切换滤镜状态，不能替换其 Element',
        );

        resizing.value = false;
        await tester.pump();
        expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

        // 非 resize 状态下仍保留原有淡出尾部优化。
        opacityController.value = 0;
        await tester.pump();
        expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
      },
    );

    testWidgets('replacing resizing notifier detaches the old source', (
      tester,
    ) async {
      final opacityController = AnimationController(vsync: tester, value: 1);
      final oldResizing = ValueNotifier(false);
      final replacement = ValueNotifier(false);
      addTearDown(opacityController.dispose);
      addTearDown(oldResizing.dispose);
      addTearDown(replacement.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: ControlBar(
                vm: buildVm(engine),
                opacity: opacityController,
                resizing: oldResizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final backdropFinder = find.byType(BackdropFilter);
      final initialElement = tester.element(backdropFinder);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

      // 父级改用 replacement 后，旧源应已从合并监听器解绑。
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: ControlBar(
                vm: buildVm(engine),
                opacity: opacityController,
                resizing: replacement,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      oldResizing.value = true;
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);
      expect(tester.element(backdropFinder), same(initialElement));

      replacement.value = true;
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);
      expect(tester.element(backdropFinder), same(initialElement));
    });
  });
}
