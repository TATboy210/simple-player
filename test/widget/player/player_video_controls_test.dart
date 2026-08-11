import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// 通过 GlobalKey 在两个 slot 间移动 child，覆盖 Flutter reparent 生命周期。
class _ReparentHost extends StatefulWidget {
  const _ReparentHost({super.key, required this.childBuilder});

  /// 每次 host 重建都生成新的 widget 实例，确保同 key 的 State 走 didUpdateWidget。
  final Widget Function() childBuilder;

  @override
  State<_ReparentHost> createState() => _ReparentHostState();
}

class _ReparentHostState extends State<_ReparentHost> {
  bool _moved = false;

  void moveChild() => setState(() => _moved = !_moved);

  /// 生成新的 child widget，显式覆盖 reparent 后的 didUpdateWidget 路径。
  void rebuildChild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final child = widget.childBuilder();
    return Scaffold(
      body: Stack(
        children: [
          if (!_moved) Positioned.fill(child: Center(child: child)),
          if (_moved)
            Positioned.fill(
              child: Align(alignment: Alignment.center, child: child),
            ),
        ],
      ),
    );
  }
}

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

  test('dispose 后旧 port stream 不再更新 notifier', () async {
    final disposablePort = FakePlayerControls();
    final disposableEngine = FakeEngine();
    final disposableState = PlayerControlsState(
      disposablePort,
      engine: disposableEngine,
    )..init();

    disposablePort.emitPosition(const Duration(milliseconds: 1800));
    await Future<void>.delayed(Duration.zero);
    expect(disposableState.positionMs.value, 1800);

    expect(disposablePort.hasListeners, isTrue);
    disposableState.dispose();
    expect(disposablePort.hasListeners, isFalse);
    final positionAfterDispose = disposableState.positionMs.value;
    final isPlayingAfterDispose = disposableState.isPlaying.value;
    disposablePort.emitPosition(const Duration(milliseconds: 7200));
    disposablePort.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);
    expect(disposableState.positionMs.value, positionAfterDispose);
    expect(disposableState.isPlaying.value, isPlayingAfterDispose);

    disposablePort.dispose();
    disposableEngine.dispose();
  });

  test('updateSources 迁移到新 port 和 engine 并解绑旧数据源', () async {
    final replacementPort = FakePlayerControls(
      isPlayingNow: true,
      positionNow: const Duration(milliseconds: 1200),
      volumeNow: 40,
    );
    final replacementEngine = FakeEngine();
    addTearDown(replacementPort.dispose);
    addTearDown(replacementEngine.dispose);

    state.updateSources(replacementPort, engine: replacementEngine);

    expect(state.isPlaying.value, isTrue);
    expect(state.positionMs.value, 1200);
    expect(state.volume01.value, closeTo(0.4, 1e-9));

    // 旧 port 已取消订阅，事件不能再污染当前控制状态。
    port.emitPosition(const Duration(milliseconds: 9000));
    port.emitPlaying(false);
    await Future<void>.delayed(Duration.zero);
    expect(state.positionMs.value, 1200);
    expect(state.isPlaying.value, isTrue);

    replacementPort.emitPosition(const Duration(milliseconds: 2400));
    replacementPort.emitPlaying(false);
    await Future<void>.delayed(Duration.zero);
    expect(state.positionMs.value, 2400);
    expect(state.isPlaying.value, isFalse);

    state.setVolume(0.25);
    state.toggleMute();
    state.setRate(1.5);
    expect(replacementEngine.lastSetVolumeValue, 0.25);
    expect(replacementEngine.isMuted.value, isTrue);
    expect(replacementPort.lastRate, 1.5);
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

    testWidgets('GlobalKey reparent 后恢复 engine、resize 与字幕监听', (tester) async {
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      final resizing = ValueNotifier<bool>(false);
      addTearDown(resizing.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: widgetEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
                resizing: resizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final originalState = controlsKey.currentState;
      video.player.emitPlaying(true);
      await tester.pump();
      // 等待既有 auto-hide 延迟，制造 visible=true → false 的真实变化。
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed + 1));
      final hiddenPaddingCalls = video.subtitlePaddingCallCount;

      hostKey.currentState!.moveChild();
      await tester.pump();

      expect(controlsKey.currentState, same(originalState));
      expect(video.subtitlePaddingCallCount, greaterThan(hiddenPaddingCalls));

      // activate 后 visible listener 必须恢复；playing=false 会重新显示并更新安全区。
      video.player.emitPlaying(false);
      await tester.pump();
      expect(
        video.lastSubtitlePadding,
        const EdgeInsets.only(
          bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
        ),
      );

      // 可见状态下再次 reparent，padding 仍只能包含一次控制栏 inset。
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(
        video.lastSubtitlePadding,
        const EdgeInsets.only(
          bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
        ),
      );

      // activate 后 fullscreen 查询也应恢复到当前 route 端口。
      final fullscreenReadsAfterActivate = video.isFullscreenReadCount;
      video.isFullscreen = true;
      hostKey.currentState!.rebuildChild();
      await tester.pump();
      expect(
        video.isFullscreenReadCount,
        greaterThan(fullscreenReadsAfterActivate),
      );

      widgetEngine.play();
      await tester.pump();
      final backdropFinder = find.byType(BackdropFilter, skipOffstage: false);
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);

      resizing.value = true;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isFalse);

      resizing.value = false;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdropFinder).enabled, isTrue);
    });

    testWidgets('reparent 同时替换全部 source 后只响应新依赖', (tester) async {
      final replacementVideo = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
        isFullscreen: true,
        subtitlePadding: const EdgeInsets.only(top: 7),
      );
      final replacementEngine = FakeEngine();
      final oldResizing = ValueNotifier<bool>(false);
      final replacementResizing = ValueNotifier<bool>(false);
      final oldFileName = currentFileName;
      final replacementFileName = ValueNotifier<String>('replacement.mp4');
      addTearDown(replacementVideo.dispose);
      addTearDown(replacementEngine.dispose);
      addTearDown(oldResizing.dispose);
      addTearDown(replacementResizing.dispose);
      addTearDown(replacementFileName.dispose);

      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      var activeVideo = video;
      var activeEngine = widgetEngine;
      ValueListenable<bool> activeResizing = oldResizing;
      ValueListenable<String> activeFileName = oldFileName;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: activeVideo,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: activeFileName,
                openFileEnabled: openFileEnabled,
                resizing: activeResizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final originalState = controlsKey.currentState;

      // 在同一父树更新中替换全部外部 source 并移动 GlobalKey，覆盖
      // didUpdateWidget 与 deactivate/activate 的交错顺序。
      activeVideo = replacementVideo;
      activeEngine = replacementEngine;
      activeResizing = replacementResizing;
      activeFileName = replacementFileName;
      hostKey.currentState!.moveChild();
      await tester.pump();

      expect(controlsKey.currentState, same(originalState));
      expect(video.player.hasListeners, isFalse);
      expect(replacementVideo.player.hasListeners, isTrue);
      expect(replacementVideo.player.streamListenAccessCount, 8);
      expect(find.text('replacement.mp4'), findsOneWidget);
      expect(
        replacementVideo.lastSubtitlePadding,
        const EdgeInsets.only(
          top: 7,
          bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
        ),
      );

      // 排空本控件已知的动画帧，再记录旧 source 后续事件不可产生的副作用。
      await tester.pump(const Duration(milliseconds: Tokens.durationControlsFade + 1));
      final newPaddingBeforeOldEvents = replacementVideo.subtitlePaddingHistory.length;
      final newFullscreenReadsBeforeOldEvents = replacementVideo.isFullscreenReadCount;
      final sliderValuesBeforeOldEvents = tester
          .widgetList<Slider>(find.byType(Slider))
          .map((slider) => slider.value)
          .toList(growable: false);
      oldFileName.value = 'stale.mp4';
      oldResizing.value = true;
      video.player.emitPlaying(true);
      video.player.emitPosition(const Duration(milliseconds: 9000));
      widgetEngine.state.value = MediaState.idle;
      await tester.pump();

      expect(find.text('replacement.mp4'), findsOneWidget);
      expect(find.text('stale.mp4'), findsNothing);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .map((slider) => slider.value)
            .toList(growable: false),
        sliderValuesBeforeOldEvents,
        reason: '旧 player position 事件不得驱动当前进度条。',
      );
      expect(replacementVideo.subtitlePaddingHistory.length, newPaddingBeforeOldEvents);
      expect(replacementVideo.isFullscreenReadCount, newFullscreenReadsBeforeOldEvents);
      expect(video.player.hasListeners, isFalse);

      // 每一种新 source 仍驱动当前控件：标题、resize、player/engine 与 route port。
      replacementFileName.value = 'latest.mp4';
      replacementResizing.value = true;
      replacementVideo.player.emitPosition(const Duration(milliseconds: 2400));
      replacementEngine.state.value = MediaState.playing;
      await tester.pump();
      expect(find.text('latest.mp4'), findsOneWidget);
      final backdrop = find.byType(BackdropFilter, skipOffstage: false);
      expect(tester.widget<BackdropFilter>(backdrop).enabled, isFalse);
      replacementResizing.value = false;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);

      // 重复 reparent 必须保持 State 和原本那一轮八条 stream subscription。
      hostKey.currentState!.moveChild();
      await tester.pump();
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(controlsKey.currentState, same(originalState));
      expect(replacementVideo.player.streamListenAccessCount, 8);
    });

    testWidgets('subtitle padding 按 source base 恢复且 replacement 后隔离旧 route', (tester) async {
      final firstBase = const EdgeInsets.only(left: 3, top: 4);
      final secondBase = const EdgeInsets.only(right: 5, bottom: 6);
      final firstVideo = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
        subtitlePadding: firstBase,
      );
      final secondVideo = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
        subtitlePadding: secondBase,
      );
      final secondEngine = FakeEngine();
      final resizing = ValueNotifier<bool>(false);
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      var activeVideo = firstVideo;
      var activeEngine = widgetEngine;
      addTearDown(firstVideo.dispose);
      addTearDown(secondVideo.dispose);
      addTearDown(secondEngine.dispose);
      addTearDown(resizing.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: activeVideo,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
                resizing: resizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstVisible = firstBase + const EdgeInsets.only(
        bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
      );
      expect(firstVideo.lastSubtitlePadding, firstVisible);

      // 真实 auto-hide 写回 base；随后显示与两次 reparent 都只能加一次 inset。
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );
      expect(firstVideo.lastSubtitlePadding, firstBase);
      firstVideo.player.emitPlaying(false);
      await tester.pump();
      expect(firstVideo.lastSubtitlePadding, firstVisible);
      hostKey.currentState!.moveChild();
      await tester.pump();
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(firstVideo.lastSubtitlePadding, firstVisible);

      // source replacement 在当前可见态立即使用第二个 source 自己的 base。
      final firstHistoryAtReplacement = firstVideo.subtitlePaddingHistory.length;
      activeVideo = secondVideo;
      activeEngine = secondEngine;
      hostKey.currentState!.rebuildChild();
      await tester.pump();
      final secondVisible = secondBase + const EdgeInsets.only(
        bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
      );
      expect(secondVideo.lastSubtitlePadding, secondVisible);

      // 已替换的 route 不得再被 player、engine 或 resize 的旧事件写入。
      firstVideo.player.emitPlaying(true);
      widgetEngine.state.value = MediaState.playing;
      resizing.value = true;
      await tester.pump();
      expect(firstVideo.subtitlePaddingHistory.length, firstHistoryAtReplacement);

      // 当前 source 在 hide/re-show 中仍以自己的 base 计算，且不累加 inset。
      resizing.value = false;
      secondVideo.player.emitPlaying(true);
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );
      expect(secondVideo.lastSubtitlePadding, secondBase);
      secondVideo.player.emitPlaying(false);
      await tester.pump();
      expect(secondVideo.lastSubtitlePadding, secondVisible);

      // 卸载后所有旧/新外部输入都不可继续写 route-local padding。
      final secondHistoryAtDispose = secondVideo.subtitlePaddingHistory.length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      firstVideo.player.emitPlaying(false);
      secondVideo.player.emitPlaying(true);
      widgetEngine.state.value = MediaState.idle;
      secondEngine.state.value = MediaState.playing;
      resizing.value = true;
      currentFileName.value = 'after-dispose.mp4';
      await tester.pump();
      expect(secondVideo.subtitlePaddingHistory.length, secondHistoryAtDispose);
      expect(firstVideo.subtitlePaddingHistory.length, firstHistoryAtReplacement);
    });

    testWidgets('替换 PlayerVideoControls source 后只响应新 port 和 engine', (
      tester,
    ) async {
      final replacementVideo = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
        isFullscreen: true,
      );
      final replacementEngine = FakeEngine();
      addTearDown(replacementVideo.dispose);
      addTearDown(replacementEngine.dispose);

      final controlsKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: widgetEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 保持父级结构和 GlobalKey 不变，只替换 source，确保触发 didUpdateWidget。
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: replacementVideo,
                engine: replacementEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 旧 source 的事件不能再驱动控件；新 source 的 fullscreen 快照已在
      // didUpdateWidget 中读取，且后续新 engine 状态变化仍可驱动外壳。
      video.player.emitPlaying(true);
      replacementEngine.state.value = MediaState.playing;
      await tester.pump();
      expect(replacementVideo.isFullscreenReadCount, greaterThan(0));

      replacementVideo.player.emitPlaying(false);
      await tester.pump();
      replacementVideo.isFullscreen = false;
      currentFileName.value = 'replacement.mp4';
      await tester.pump();
      expect(replacementVideo.isFullscreenReadCount, greaterThan(1));
    });

    testWidgets('替换不同 video port 但共享 player 后立即同步字幕安全区', (
      tester,
    ) async {
      final replacementVideo = FakeVideoControlsPort(
        player: video.player,
        subtitlePadding: const EdgeInsets.only(top: 4),
      );
      final replacementEngine = FakeEngine();
      addTearDown(replacementEngine.dispose);

      final controlsKey = GlobalKey();
      var activeVideo = video;
      var activeEngine = widgetEngine;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: activeVideo,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 只替换 VideoControlsPort，保持底层 PlayerPort identity 不变；
      // 当前控制栏仍可见时，新 VideoState 也必须立即获得安全区。
      activeVideo = replacementVideo;
      activeEngine = replacementEngine;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: activeVideo,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        replacementVideo.lastSubtitlePadding,
        const EdgeInsets.only(
          top: 4,
          bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
        ),
      );
    });

    testWidgets('仅替换 engine 且复用 video port 时字幕安全区不重复累加', (
      tester,
    ) async {
      final replacementEngine = FakeEngine();
      addTearDown(replacementEngine.dispose);
      final controlsKey = GlobalKey();
      var activeEngine = widgetEngine;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final expectedPadding = const EdgeInsets.only(
        bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
      );
      expect(video.lastSubtitlePadding, expectedPadding);

      // 仅替换 engine，保留同一个 VideoControlsPort；旧 padding 已包含一次 inset，
      // 新一轮同步不得把它误当作基础值再叠加一次。
      activeEngine = replacementEngine;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(video.lastSubtitlePadding, expectedPadding);
      expect(video.subtitlePaddingHistory, isNotEmpty);
      expect(video.subtitlePaddingHistory.last, expectedPadding);
    });

    testWidgets('多次 reparent 后生命周期 listener 不重复且卸载后失效', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(false);
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      addTearDown(resizing.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: widgetEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
                resizing: resizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 多次跨父节点移动，覆盖 deactivate/activate 重复进入的路径。
      hostKey.currentState!.moveChild();
      await tester.pump();
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(controlsKey.currentState, isNotNull);
      expect(video.player.hasListeners, isTrue);
      expect(video.player.streamListenAccessCount, 8);
      // 第二次 reparent 不能重新读取 8 条 stream，否则意味着重复初始化订阅。
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(video.player.streamListenAccessCount, 8);

      // 反复切换外部 resize source，验证 activate 后仍只保留当前 listener；
      // 这里不等待 auto-hide timer，避免把生命周期测试绑定到动画时钟。
      resizing.value = true;
      await tester.pump();
      expect(find.byType(BackdropFilter, skipOffstage: false), findsOneWidget);
      resizing.value = false;
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(video.player.hasListeners, isFalse);
      final paddingCallsAfterDispose = video.subtitlePaddingCallCount;

      resizing.value = true;
      widgetEngine.state.value = MediaState.playing;
      video.player.emitPlaying(true);
      await tester.pump();
      expect(video.subtitlePaddingCallCount, paddingCallsAfterDispose);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reparent 后替换 source 再卸载不会泄漏旧新订阅', (tester) async {
      final replacementVideo = FakeVideoControlsPort(
        player: FakePlayerControls(isPlayingNow: true),
      );
      final replacementEngine = FakeEngine();
      final resizing = ValueNotifier<bool>(false);
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      var activeVideo = video;
      var activeEngine = widgetEngine;
      addTearDown(replacementVideo.dispose);
      addTearDown(replacementEngine.dispose);
      addTearDown(resizing.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: activeVideo,
                engine: activeEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
                resizing: resizing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      hostKey.currentState!.moveChild();
      await tester.pump();
      activeVideo = replacementVideo;
      activeEngine = replacementEngine;
      hostKey.currentState!.rebuildChild();
      await tester.pump();

      expect(controlsKey.currentState, isNotNull);
      expect(video.player.hasListeners, isFalse);
      expect(replacementVideo.player.hasListeners, isTrue);
      expect(replacementVideo.player.streamListenAccessCount, 8);
      // FakeEngine 自身有内部状态派生 listener；旧/new source 的解绑由
      // stream 事件隔离和卸载后的无更新断言共同覆盖。
      final paddingCallsBeforeDispose = replacementVideo.subtitlePaddingCallCount;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(replacementVideo.player.hasListeners, isFalse);
      video.player.emitPosition(const Duration(milliseconds: 9000));
      replacementVideo.player.emitPosition(const Duration(milliseconds: 12000));
      widgetEngine.state.value = MediaState.idle;
      replacementEngine.state.value = MediaState.playing;
      resizing.value = true;
      await tester.pump();

      expect(
        replacementVideo.subtitlePaddingCallCount,
        paddingCallsBeforeDispose,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('卸载 PlayerVideoControls 后解绑全部生命周期监听器', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(false);
      addTearDown(resizing.dispose);

      await pumpControls(
        tester,
        resizing: resizing,
        actions: const PlayerActions(),
      );
      expect(video.player.hasListeners, isTrue);
      final paddingCallsBeforeDispose = video.subtitlePaddingCallCount;

      // 先真正卸载 State，再驱动所有外部 source；dispose 后不应留下回调入口。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(video.player.hasListeners, isFalse);

      widgetEngine.state.value = MediaState.playing;
      resizing.value = true;
      video.player.emitPlaying(true);
      video.player.emitPosition(const Duration(milliseconds: 9000));
      await tester.pump();

      expect(video.subtitlePaddingCallCount, paddingCallsBeforeDispose);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('VideoState 未挂载时字幕同步被生命周期 guard 拦截', (
      tester,
    ) async {
      await pumpControls(tester, actions: const PlayerActions());
      final paddingCallsBeforeUnmount = video.subtitlePaddingCallCount;

      // 模拟 media_kit VideoState 已离开树但 controls State 尚未 dispose 的窗口。
      video.isMounted = false;
      video.player.emitPlaying(true);
      await tester.pump();
      expect(video.subtitlePaddingCallCount, paddingCallsBeforeUnmount);

      // source 恢复挂载后，通过真实 reparent 触发 activate，同步安全区应恢复。
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: widgetEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      video.isMounted = true;
      hostKey.currentState!.moveChild();
      await tester.pump();
      expect(
        video.subtitlePaddingCallCount,
        greaterThan(paddingCallsBeforeUnmount),
      );
    });

    testWidgets('单击后卸载 PlayerVideoControls 会取消双击检测 timer', (
      tester,
    ) async {
      var toggleCount = 0;
      await pumpControls(
        tester,
        actions: PlayerActions(onToggleFullscreen: () => toggleCount++),
      );

      // 控件上方的手势区第一次点击会创建 400ms 双击检测 timer。
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 401));

      expect(toggleCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('deactivate 期间不读取 fullscreen，activate 后恢复读取', (
      tester,
    ) async {
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _ReparentHost(
              key: hostKey,
              childBuilder: () => PlayerVideoControls(
                key: controlsKey,
                video: video,
                engine: widgetEngine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                openFileEnabled: openFileEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final readsBeforeReparent = video.isFullscreenReadCount;
      hostKey.currentState!.moveChild();
      await tester.pump();

      // reparent 完成后 State 必须仍然有效，且 activate 路径恢复 fullscreen 查询。
      expect(controlsKey.currentState, isNotNull);
      expect(video.isFullscreenReadCount, greaterThan(readsBeforeReparent));
    });

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
