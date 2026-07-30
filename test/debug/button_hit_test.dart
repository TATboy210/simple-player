/// R1 调试测试 — 验证按钮在 ControlsOverlay 内是否可点击
///
/// 运行: flutter test test/debug/button_hit_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import '../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    // 匹配生产环境:app 启动时调 KernelLoggerImpl.init()。测试中 transitionTo
    // 非法转换会触发 KernelLoggerImpl.I.warn,未 init 时抛 StateError(如 idle→idle)。
    KernelLoggerImpl.init();
    engine = FakeEngine();
    engine.state.value = MediaState.playing;
    engine.duration.value = 60000;
    engine.position.value = 10000;
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildFullOverlay({PlayerActions? actions}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ControlsOverlay(
            engine: engine,
            actions:
                actions ??
                const PlayerActions(onPrevious: _noop, onNext: _noop),
          ),
        ),
      ),
    );
  }

  Widget buildControlBarOnly({PlayerActions? actions, bool isIdle = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: ControlBar(
            engine: engine,
            isIdle: isIdle,
            actions:
                actions ??
                const PlayerActions(onPrevious: _noop, onNext: _noop),
          ),
        ),
      ),
    );
  }

  group('R1 Debug: Button hit test', () {
    testWidgets('ControlBar only — play/pause button tappable', (tester) async {
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      final playButton = find.byIcon(Icons.pause);
      expect(playButton, findsOneWidget, reason: 'Should find pause icon');

      await tester.tap(playButton);
      await tester.pump();

      expect(
        engine.state.value,
        MediaState.paused,
        reason: 'togglePlayPause should change state to paused',
      );
    });

    testWidgets('ControlsOverlay — play/pause button tappable', (tester) async {
      await tester.pumpWidget(buildFullOverlay());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playButton = find.byIcon(Icons.pause);
      expect(
        playButton,
        findsOneWidget,
        reason: 'Should find pause icon inside ControlsOverlay',
      );

      await tester.tap(playButton);
      await tester.pump();

      expect(
        engine.state.value,
        MediaState.paused,
        reason: 'togglePlayPause should work through ControlsOverlay',
      );
    });

    testWidgets('ControlsOverlay — previous button tappable', (tester) async {
      var prevCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: () => prevCalled = true,
            onNext: _noop,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final prevButton = find.byIcon(Icons.skip_previous);
      expect(prevButton, findsOneWidget);

      await tester.tap(prevButton);
      await tester.pump();

      expect(prevCalled, isTrue, reason: 'onPrevious should be called');
    });

    testWidgets('ControlsOverlay — next button tappable', (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: _noop,
            onNext: () => nextCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final nextButton = find.byIcon(Icons.skip_next);
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(nextCalled, isTrue, reason: 'onNext should be called');
    });

    testWidgets('ControlsOverlay — fullscreen button tappable', (tester) async {
      var fsCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: _noop,
            onNext: _noop,
            onToggleFullscreen: () => fsCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fsButton = find.byIcon(Icons.fullscreen);
      expect(fsButton, findsOneWidget);

      await tester.tap(fsButton);
      await tester.pump();

      expect(fsCalled, isTrue, reason: 'onToggleFullscreen should be called');
    });

    testWidgets('idle state routes stop and play taps to the engine', (
      tester,
    ) async {
      // RED: CenterGroup currently disables every button when isIdle is true.
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildControlBarOnly(isIdle: true));
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.stop));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.stopCallCount, 1);
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('opening state keeps play button interactive', (tester) async {
      // RED contract: opening must route input to the idempotent engine, not no-op.
      engine.state.value = MediaState.opening;
      await tester.pumpWidget(buildControlBarOnly(isIdle: true));
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('replay 10 requests a 10000ms backward skip', (tester) async {
      // RED: current CenterGroup passes a seconds token (10) as milliseconds.
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();

      // Assert
      expect(engine.skipBackCallCount, 1);
      expect(engine.lastSkipBackMs, 10000);
    });

    testWidgets('forward 30 requests a 30000ms forward skip', (tester) async {
      // RED: current CenterGroup passes a seconds token (30) as milliseconds.
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pump();

      // Assert
      expect(engine.skipForwardCallCount, 1);
      expect(engine.lastSkipForwardMs, 30000);
    });

    testWidgets('seeking state routes two consecutive forward taps', (
      tester,
    ) async {
      // RED contract: a transient seek must not suppress the latest user intent.
      engine.isSeeking.value = true;
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pump();

      // Assert
      expect(engine.skipForwardCallCount, 2);
    });

    testWidgets('hidden controls remove center buttons from hit-test', (
      tester,
    ) async {
      // 契约:控制栏隐藏(visible=false,完全透明)后,ControlBar 从 hit-test 树
      // 移除,tap 穿透到上层手势区/视频区,不触发不可见按钮(避免误触)。
      // ErrorBanner 独立可见且不受 ControlBar 可见性连累(另测)。
      await tester.pumpWidget(buildFullOverlay());
      await tester.pump();

      // Act: playing controls hide after the windowed five-second delay.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: 隐藏态(visible=false)ControlBar 被 Visibility+Offstage 移出可见树,
      // find.byIcon 默认 skipOffstage=true 故找不到 stop —— 契约:隐藏态按钮不可见,
      // 不会因透明叠加层抢点击而误触发(原 P3:IgnorePointer 连累整层的问题已修复)。
      expect(find.byIcon(Icons.stop), findsNothing);
      expect(engine.stopCallCount, 0);
    });
  });
}

void _noop() {}
