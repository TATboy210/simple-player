import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

/// 空置态播放命令守卫回归测试 (bug: 空置态点击播放按钮视频区域变黑).
///
/// 根因: 引擎 `play()` 未 guard `!hasMedia`, state 被误写 playing →
/// `emptyActive=false` → 极光空置页卸载 → 露出无媒体的黑色 Video.
/// 修复: `play()` 空置幂等忽略, state 保持 idle, 空置页不卸载;
/// 按钮仍可点且命令照常路由到引擎 (UI 永远可交互惯例).
void main() {
  late FakeEngine engine;
  late FakeVideoControlsPort video;
  late ValueNotifier<String> currentFileName;
  late ValueNotifier<WindowMode> windowMode;

  setUp(() {
    engine = FakeEngine();
    video = FakeVideoControlsPort();
    currentFileName = ValueNotifier<String>('');
    windowMode = ValueNotifier<WindowMode>(WindowMode.windowed);
  });

  tearDown(() {
    currentFileName.dispose();
    windowMode.dispose();
    video.dispose();
    engine.dispose();
  });

  Future<void> pumpControls(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: PlayerVideoControls(
              video: video,
              engine: engine,
              // onPlayPause 直连 engine.togglePlayPause — 模拟生产链路
              // PlayerScreen → PlaybackController.togglePlayPause → engine.
              actions: PlayerActions(onPlayPause: engine.togglePlayPause),
              currentFileName: currentFileName,
              windowMode: windowMode,
              emptyState: EmptyState(engineState: engine.state),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('空置态点击播放按钮 — 空置页保持不变黑', (tester) async {
    await pumpControls(tester);

    // 前置: 空置态 (未加载媒体) — 极光空置页可见.
    expect(engine.hasMedia, isFalse);
    expect(find.byType(EmptyState), findsOneWidget);

    // 点击控制栏播放按钮.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    // 命令照常路由到引擎 (UI 可交互契约).
    expect(engine.togglePlayPauseCallCount, 1);
    // 引擎幂等忽略: state 保持 idle, 空置页不卸载.
    expect(engine.state.value, MediaState.idle);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('空置态按 Space — 空置页保持不变黑', (tester) async {
    await pumpControls(tester);

    expect(find.byType(EmptyState), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(engine.togglePlayPauseCallCount, 1);
    expect(engine.state.value, MediaState.idle);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('加载媒体后播放正常 — guard 不误伤正常流', (tester) async {
    await pumpControls(tester);

    engine.configureMedia(durationMs: 60000);
    await engine.open('/test.mp4');
    await tester.pump();

    engine.play();
    await tester.pump();

    expect(engine.state.value, MediaState.playing);
    // 播放中空置页消失 (正常行为).
    expect(find.byType(EmptyState), findsNothing);
  });
}
