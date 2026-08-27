import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// Moves one keyed controls subtree between slots to exercise reparent lifecycle.
class _ReparentHost extends StatefulWidget {
  const _ReparentHost({super.key, required this.child});

  final Widget child;

  @override
  State<_ReparentHost> createState() => _ReparentHostState();
}

class _ReparentHostState extends State<_ReparentHost> {
  bool _moved = false;

  /// Alternates the keyed child between parents without replacing its State.
  void move() => setState(() => _moved = !_moved);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (_moved) Align(child: widget.child) else Center(child: widget.child),
    ],
  );
}

/// Builds a route-local controls tree without constructing a native Video.
Widget _controlsApp({
  required Key key,
  required FakeVideoControlsPort video,
  required FakeEngine engine,
  required ValueListenable<String> title,
  required ValueListenable<bool> resizing,
  required ValueListenable<WindowMode> windowMode,
  GlobalKey<_ReparentHostState>? hostKey,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox(
      width: 1280,
      height: 720,
      child: _ReparentHost(
        key: hostKey,
        child: PlayerVideoControls(
          key: key,
          video: video,
          engine: engine,
          actions: const PlayerActions(),
          currentFileName: title,
          windowMode: windowMode,
          resizing: resizing,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'replacement isolates old controls sources and dispose silences active sources',
    (tester) async {
      final oldVideo = FakeVideoControlsPort(player: FakePlayerControls());
      final newVideo = FakeVideoControlsPort(player: FakePlayerControls());
      final oldEngine = FakeEngine();
      final newEngine = FakeEngine();
      final oldTitle = ValueNotifier<String>('old.mp4');
      final newTitle = ValueNotifier<String>('new.mp4');
      final oldResizing = ValueNotifier<bool>(false);
      final newResizing = ValueNotifier<bool>(false);
      final windowMode = ValueNotifier<WindowMode>(WindowMode.windowed);
      final controlsKey = GlobalKey();
      final hostKey = GlobalKey<_ReparentHostState>();

      addTearDown(oldVideo.dispose);
      addTearDown(newVideo.dispose);
      addTearDown(oldEngine.dispose);
      addTearDown(newEngine.dispose);
      addTearDown(oldTitle.dispose);
      addTearDown(newTitle.dispose);
      addTearDown(oldResizing.dispose);
      addTearDown(newResizing.dispose);
      addTearDown(windowMode.dispose);

      await tester.pumpWidget(
        _controlsApp(
          key: controlsKey,
          video: oldVideo,
          engine: oldEngine,
          title: oldTitle,
          resizing: oldResizing,
          windowMode: windowMode,
          hostKey: hostKey,
        ),
      );
      await tester.pump();
      final retainedState = controlsKey.currentState;

      await tester.pumpWidget(
        _controlsApp(
          key: controlsKey,
          video: newVideo,
          engine: newEngine,
          title: newTitle,
          resizing: newResizing,
          windowMode: windowMode,
          hostKey: hostKey,
        ),
      );
      await tester.pump();

      expect(controlsKey.currentState, same(retainedState));
      expect(oldVideo.player.hasListeners, isFalse);
      expect(newVideo.player.hasListeners, isTrue);
      expect(newVideo.player.streamListenAccessCount, 8);
      expect(find.text('new.mp4'), findsOneWidget);

      // Two deactivate/activate rounds must retain the existing eight streams.
      hostKey.currentState!.move();
      await tester.pump();
      hostKey.currentState!.move();
      await tester.pump();
      expect(controlsKey.currentState, same(retainedState));
      expect(newVideo.player.streamListenAccessCount, 8);

      final paddingBeforeOldEvents = newVideo.subtitlePaddingHistory.length;
      oldTitle.value = 'stale.mp4';
      oldResizing.value = true;
      oldEngine.state.value = MediaState.playing;
      oldVideo.player.emitPlaying(true);
      await tester.pump();
      expect(find.text('stale.mp4'), findsNothing);
      expect(newVideo.subtitlePaddingHistory.length, paddingBeforeOldEvents);

      newTitle.value = 'latest.mp4';
      newResizing.value = true;
      await tester.pump();
      expect(find.text('latest.mp4'), findsOneWidget);
      // 视觉恒定契约：resize 会话期间玻璃滤镜保持启用。
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );

      final paddingAtDispose = newVideo.subtitlePaddingHistory.length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      newResizing.value = false;
      newEngine.state.value = MediaState.idle;
      newVideo.player.emitPlaying(true);
      await tester.pump();
      expect(newVideo.player.hasListeners, isFalse);
      expect(newVideo.subtitlePaddingHistory.length, paddingAtDispose);
    },
  );

  testWidgets(
    'ControlBar blur is not driven by any resize source, old or new',
    (tester) async {
      final oldOpacity = AnimationController(
        vsync: tester,
        value: 1,
        duration: const Duration(milliseconds: 1),
      );
      final newOpacity = AnimationController(
        vsync: tester,
        value: 1,
        duration: const Duration(milliseconds: 1),
      );
      final oldResizing = ValueNotifier<bool>(false);
      final newResizing = ValueNotifier<bool>(false);
      final isPlaying = ValueNotifier<bool>(false);
      final position = ValueNotifier<int>(0);
      final duration = ValueNotifier<int>(1000);
      final volume = ValueNotifier<double>(1);
      final isMuted = ValueNotifier<bool>(false);
      final rate = ValueNotifier<double>(1);
      final isFullscreen = ValueNotifier<bool>(false);

      addTearDown(oldOpacity.dispose);
      addTearDown(newOpacity.dispose);
      addTearDown(oldResizing.dispose);
      addTearDown(newResizing.dispose);
      addTearDown(isPlaying.dispose);
      addTearDown(position.dispose);
      addTearDown(duration.dispose);
      addTearDown(volume.dispose);
      addTearDown(isMuted.dispose);
      addTearDown(rate.dispose);
      addTearDown(isFullscreen.dispose);

      Widget buildBar(
        Animation<double> opacity,
        ValueListenable<bool> resizing,
      ) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ControlBar(
            vm: ControlBarViewModel(
              isPlaying: isPlaying,
              position: position,
              duration: duration,
              volume: volume,
              isMuted: isMuted,
              rate: rate,
              isFullscreen: isFullscreen,
              onSeek: (_) {},
              onPlayPause: () {},
              onSeekBack: (_) {},
              onSeekForward: (_) {},
              onToggleMute: () {},
              onSetVolume: (_) {},
              onSetRate: (_) {},
            ),
            actions: const PlayerActions(),
            opacity: opacity,
            resizing: resizing,
          ),
        ),
      );

      await tester.pumpWidget(buildBar(oldOpacity, oldResizing));
      await tester.pumpWidget(buildBar(newOpacity, newResizing));
      // blur 层不订阅任何 resize 源 — 被替换下来的旧源与当前新源的
      // 变化都不得改变滤镜状态；启停只由 opacity 决定（control_bar_test
      // 已覆盖 opacity 契约）。
      oldResizing.value = true;
      await tester.pump();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );

      newResizing.value = true;
      await tester.pump();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );
    },
  );
}
