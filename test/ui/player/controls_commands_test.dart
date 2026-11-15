// ignore_for_file: no-empty-block
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';
import 'package:simple_player_flutter/ui/player/controls_derived_signals.dart';
import 'package:simple_player_flutter/ui/player/controls_keyboard.dart';
import 'package:simple_player_flutter/ui/player/controls_tap_controller.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_controls_host.dart';
import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

/// 在测试树里取一个真实 BuildContext，构造 [FakeControlsHost]。
Future<FakeControlsHost> _host(
  WidgetTester tester, {
  PlayerActions actions = const PlayerActions(),
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  final engine = FakeEngine();
  final video = FakeVideoControlsPort();
  final playing = ValueNotifier<bool>(false);
  final autoHide =
      AutoHideController(vsync: tester, isPlaying: playing, isFullscreen: false)
        ..init()
        // 钉住以取消 init 启动的 3s 隐藏计时，避免测试结束时残留 Timer
        ..pinned = true;
  addTearDown(() {
    autoHide.dispose();
    playing.dispose();
    video.dispose();
    engine.dispose();
  });
  return FakeControlsHost(
    video: video,
    engine: engine,
    autoHide: autoHide,
    context: captured,
    actions: actions,
  );
}

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyRepeatEvent _repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

FakeVideoControlsPort _port(FakeControlsHost host) =>
    host.video as FakeVideoControlsPort;

void main() {
  group('ControlsCommands', () {
    testWidgets('toggleFullscreen 先回调宿主再触碰视频端口', (tester) async {
      var hostCalls = 0;
      final host = await _host(
        tester,
        actions: PlayerActions(onToggleFullscreen: () => hostCalls++),
      );

      ControlsCommands(host).toggleFullscreen();

      expect(hostCalls, 1);
      expect(_port(host).toggleFullscreenCallCount, 1);
    });

    testWidgets('失效或端口未挂载时 toggleFullscreen 不做任何事', (tester) async {
      var calls = 0;
      final host = await _host(
        tester,
        actions: PlayerActions(onToggleFullscreen: () => calls++),
      );
      final commands = ControlsCommands(host);

      host.isAlive = false;
      commands.toggleFullscreen();
      host.isAlive = true;
      _port(host).isMounted = false;
      commands.toggleFullscreen();

      expect(calls, 0);
    });

    testWidgets('exitFullscreen 仅在全屏模式下生效', (tester) async {
      var calls = 0;
      final host = await _host(
        tester,
        actions: PlayerActions(onToggleFullscreen: () => calls++),
      );
      final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
      host.windowMode = mode;
      addTearDown(mode.dispose);
      final commands = ControlsCommands(host);

      expect(commands.exitFullscreen(), isFalse);
      expect(calls, 0);

      mode.value = WindowMode.fullscreen;
      expect(commands.exitFullscreen(), isTrue);
      expect(calls, 1);
      expect(_port(host).exitFullscreenCallCount, 1);
    });

    testWidgets('按键分发: Space/方向键与重复键门禁', (tester) async {
      var playPause = 0;
      final seeks = <String>[];
      final host = await _host(
        tester,
        actions: PlayerActions(
          onPlayPause: () => playPause++,
          onSeekBack: (ms) => seeks.add('back$ms'),
          onSeekForward: (ms) => seeks.add('fwd$ms'),
        ),
      );
      final commands = ControlsCommands(host);
      final node = FocusNode();
      addTearDown(node.dispose);

      expect(
        commands.handleKey(node, _down(LogicalKeyboardKey.space)),
        KeyEventResult.handled,
      );
      expect(playPause, 1);

      // 仅 ←/→ 的 KeyRepeat 放行
      expect(
        commands.handleKey(node, _repeat(LogicalKeyboardKey.space)),
        KeyEventResult.ignored,
      );
      expect(playPause, 1);
      commands.handleKey(node, _repeat(LogicalKeyboardKey.arrowLeft));
      commands.handleKey(node, _down(LogicalKeyboardKey.arrowRight));
      expect(seeks, ['back${Tokens.skipShortMs}', 'fwd${Tokens.skipLongMs}']);

      expect(
        commands.handleKey(node, _down(LogicalKeyboardKey.keyZ)),
        KeyEventResult.ignored,
      );
      // 窗口态 ESC 冒泡
      expect(
        commands.handleKey(node, _down(LogicalKeyboardKey.escape)),
        KeyEventResult.ignored,
      );
    });

    testWidgets('控制层失效后一律 ignored', (tester) async {
      var playPause = 0;
      final host = await _host(
        tester,
        actions: PlayerActions(onPlayPause: () => playPause++),
      );
      final node = FocusNode();
      addTearDown(node.dispose);
      host.isAlive = false;

      final result = ControlsCommands(host)
          .handleKey(node, _down(LogicalKeyboardKey.space));

      expect(result, KeyEventResult.ignored);
      expect(playPause, 0);
    });
  });

  group('ControlsTapController', () {
    testWidgets('播放列表开着时点击只关面板', (tester) async {
      var toggles = 0;
      final host = await _host(tester);
      final playlist = ValueNotifier<bool>(true);
      host.playlistVisible = playlist;
      addTearDown(playlist.dispose);
      final tap = ControlsTapController(
        host,
        toggleFullscreen: () => toggles++,
      );

      tap.handleTap();

      expect(playlist.value, isFalse);
      expect(toggles, 0);
      tap.dispose();
    });

    testWidgets('legacy 设置优先于播放列表被关闭', (tester) async {
      final host = await _host(tester);
      final settings = ValueNotifier<bool>(true);
      final playlist = ValueNotifier<bool>(true);
      host.legacySettingsVisible = settings;
      host.playlistVisible = playlist;
      addTearDown(() {
        settings.dispose();
        playlist.dispose();
      });
      final tap = ControlsTapController(host, toggleFullscreen: () {});

      tap.handleEmptyAreaTap();
      expect(settings.value, isFalse);
      expect(playlist.value, isTrue);

      tap.handleEmptyAreaTap();
      expect(playlist.value, isFalse);
      tap.dispose();
    });

    testWidgets('400ms 内第二次点击视为双击切换全屏', (tester) async {
      var toggles = 0;
      final host = await _host(tester);
      final tap = ControlsTapController(
        host,
        toggleFullscreen: () => toggles++,
      );

      tap.handleTap();
      expect(toggles, 0);
      tap.handleTap();
      expect(toggles, 1);

      tap.dispose();
    });
  });

  group('ControlsDerivedSignals', () {
    testWidgets('光标: 全屏 + 控制栏隐藏 + 无面板才隐藏', (tester) async {
      final host = await _host(tester);
      final mode = ValueNotifier<WindowMode>(WindowMode.fullscreen);
      final playlist = ValueNotifier<bool>(false);
      host.windowMode = mode;
      host.playlistVisible = playlist;
      addTearDown(() {
        mode.dispose();
        playlist.dispose();
      });
      final signals = ControlsDerivedSignals(host);
      addTearDown(signals.dispose);

      host.autoHide.visible.value = false;
      signals.recompute();
      expect(signals.cursorHidden.value, isTrue);

      playlist.value = true; // 面板开着用户仍在交互
      signals.recompute();
      expect(signals.cursorHidden.value, isFalse);

      playlist.value = false;
      host.autoHide.visible.value = true;
      signals.recompute();
      expect(signals.cursorHidden.value, isFalse);
    });

    testWidgets('语义: resize 期或隐藏期排除', (tester) async {
      final host = await _host(tester);
      final resizing = ValueNotifier<bool>(false);
      host.resizing = resizing;
      addTearDown(resizing.dispose);
      final signals = ControlsDerivedSignals(host);
      addTearDown(signals.dispose);

      signals.recompute();
      expect(signals.semanticsExcluded.value, isFalse);

      resizing.value = true;
      signals.recompute();
      expect(signals.semanticsExcluded.value, isTrue);

      resizing.value = false;
      host.autoHide.visible.value = false;
      signals.recompute();
      expect(signals.semanticsExcluded.value, isTrue);
    });
  });
}
