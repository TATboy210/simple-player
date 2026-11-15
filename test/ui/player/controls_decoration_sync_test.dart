import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';
import 'package:simple_player_flutter/ui/player/controls_decoration_sync.dart';

import '../../helpers/fake_controls_host.dart';
import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

void main() {
  late FakeEngine engine;
  late FakeVideoControlsPort video;
  late ValueNotifier<bool> playing;
  late ValueNotifier<bool> resizing;
  late ValueNotifier<WindowMode> mode;
  late AutoHideController autoHide;
  late FakeControlsHost host;
  late ControlsDecorationSync sync;
  var settled = 0;

  setUp(() {
    settled = 0;
    engine = FakeEngine();
    video = FakeVideoControlsPort();
    playing = ValueNotifier<bool>(false);
    resizing = ValueNotifier<bool>(false);
    mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  });

  Future<void> pumpSync(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    autoHide = AutoHideController(
      vsync: tester,
      isPlaying: playing,
      isFullscreen: false,
    )..init();
    // 钉住以取消 init 启动的隐藏计时，避免残留 Timer
    autoHide.pinned = true;
    host = FakeControlsHost(
      video: video,
      engine: engine,
      autoHide: autoHide,
      context: context,
    )..resizing = resizing;
    host.windowMode = mode;
    sync = ControlsDecorationSync(
      host,
      vsync: tester,
      onResizeSettled: () => settled++,
    )..init();
    addTearDown(() {
      sync.dispose();
      autoHide.dispose();
      playing.dispose();
      resizing.dispose();
      mode.dispose();
      video.dispose();
      engine.dispose();
    });
  }

  testWidgets('init 读取 windowMode 与 engine 初值', (tester) async {
    mode.value = WindowMode.fullscreen;
    await pumpSync(tester);

    expect(sync.isFullscreen.value, isTrue);
    expect(sync.isIdle.value, engine.state.value == MediaState.idle);
  });

  testWidgets('syncMode 全屏翻转同步图标信号并标记过渡', (tester) async {
    await pumpSync(tester);
    expect(sync.isFullscreen.value, isFalse);

    mode.value = WindowMode.fullscreen;
    sync.syncMode();
    expect(sync.isFullscreen.value, isTrue);

    // 全屏过渡期间 resize 不淡出 decoration；平息后清标记并回调
    resizing.value = true;
    sync.onResizeChanged();
    await tester.pump();
    expect(sync.decoration.value, 1.0);

    resizing.value = false;
    sync.onResizeChanged();
    expect(settled, 1);
    await tester.pumpAndSettle(); // 让恢复动画跑完，避免残留 ticker
  });

  testWidgets('resize 期间淡出 decoration 且忽略 engine 状态变化', (tester) async {
    await pumpSync(tester);

    resizing.value = true;
    sync.onResizeChanged();
    await tester.pumpAndSettle();
    expect(sync.decoration.value, 0.0);
    expect(sync.onEngineStateChanged(), isFalse);

    resizing.value = false;
    sync.onResizeChanged();
    await tester.pumpAndSettle();
    expect(sync.onEngineStateChanged(), isTrue);
  });
}
