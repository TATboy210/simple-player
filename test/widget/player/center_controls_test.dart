/// Contracts for the four central playback controls.
///
/// These tests describe the current interaction policy:
/// commands always reach the idempotent engine; only a loading indicator may
/// ignore input while buffering.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/shared/glass_widgets.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    // 匹配生产环境:app 启动时调 KernelLoggerImpl.init(),避免 transitionTo
    // 非法转换时 KernelLoggerImpl.I.warn 抛 StateError(见 button_hit_test)。
    KernelLoggerImpl.init();
    engine = FakeEngine();
    engine.duration.value = 120000;
    engine.position.value = 60000;
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildSubject({required Widget child, FocusScopeNode? focusScopeNode}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FocusScope(
          node: focusScopeNode,
          child: Center(child: child),
        ),
      ),
    );
  }

  CenterGroup buildCenterGroup({VoidCallback? onStop}) {
    return CenterGroup(
      isPlaying: engine.isPlayingNotifier,
      onPlayPause: engine.togglePlayPause,
      onSeekBack: engine.skipBack,
      onSeekForward: engine.skipForward,
      isIdle: engine.state.value == MediaState.idle,
      onStop: onStop ?? engine.stop,
    );
  }

  group('CenterGroup always-interactive command contract', () {
    testWidgets('idle state exposes non-null callbacks for all four buttons', (
      tester,
    ) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));
      await tester.pump();

      // Act
      final buttons = tester.widgetList<GlassButton>(find.byType(GlassButton));

      // Assert
      expect(buttons, hasLength(4));
      expect(
        buttons.every((button) => button.onPressed != null),
        isTrue,
        reason:
            'All central commands must reach the idempotent engine in idle.',
      );
    });

    testWidgets('idle PlayPauseButton routes tap to togglePlayPause', (
      tester,
    ) async {
      // RED: PlayPauseButton currently sets onPressed to null when isIdle is true.
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(
        buildSubject(
          child: PlayPauseButton(
            isPlaying: engine.isPlayingNotifier,
            onPlayPause: engine.togglePlayPause,
            isIdle: true,
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('opening PlayPauseButton routes tap rather than disabling it', (
      tester,
    ) async {
      // RED: opening is treated as idle by ControlBar and currently disables play.
      engine.state.value = MediaState.opening;
      await tester.pumpWidget(
        buildSubject(
          child: PlayPauseButton(
            isPlaying: engine.isPlayingNotifier,
            onPlayPause: engine.togglePlayPause,
            isIdle: true,
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert
      expect(engine.togglePlayPauseCallCount, 1);
    });

    testWidgets('stop routes tap through the supplied controller callback', (
      tester,
    ) async {
      var stopCount = 0;
      await tester.pumpWidget(
        buildSubject(child: buildCenterGroup(onStop: () => stopCount++)),
      );

      // Act
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      // Assert
      expect(stopCount, 1);
      expect(engine.stopCallCount, 0);
    });

    testWidgets('replay 10 requests a 10-second backward skip in milliseconds', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));

      // Act
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();

      // Assert: prevent passing the displayed seconds value (10) as milliseconds.
      expect(engine.skipBackCallCount, 1);
      expect(engine.lastSkipBackMs, Tokens.skipShortMs);
    });

    testWidgets(
      'forward 30 requests a 30-second forward skip in milliseconds',
      (tester) async {
        await tester.pumpWidget(buildSubject(child: buildCenterGroup()));

        // Act
        await tester.tap(find.byIcon(Icons.forward_30));
        await tester.pump();

        // Assert: keep the 30-second UI action aligned with the engine ms API.
        expect(engine.skipForwardCallCount, 1);
        expect(engine.lastSkipForwardMs, Tokens.skipLongMs);
      },
    );

    testWidgets('seeking CenterGroup accepts a second replay command', (
      tester,
    ) async {
      // RED contract: isSeeking must not turn command taps into a mutual exclusion gate.
      engine.isSeeking.value = true;
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();

      // Assert
      expect(engine.skipBackCallCount, 2);
    });
  });

  group('CenterGroup cross-platform keyboard and semantics contract', () {
    testWidgets('four controls follow the Tab traversal order', (tester) async {
      final scopeNode = FocusScopeNode();
      addTearDown(scopeNode.dispose);
      await tester.pumpWidget(
        buildSubject(
          focusScopeNode: scopeNode,
          child: CenterGroup(
            isPlaying: engine.isPlayingNotifier,
            onPlayPause: engine.togglePlayPause,
            onSeekBack: engine.skipBack,
            onSeekForward: engine.skipForward,
            isIdle: false,
            onStop: engine.stop,
          ),
        ),
      );
      await tester.pump();

      // 四个中央控件应按 Rewind、Play/Pause、Forward、Stop 顺序获得焦点。
      scopeNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(engine.skipBackCallCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(engine.togglePlayPauseCallCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(engine.skipForwardCallCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(engine.stopCallCount, 1);
    });

    testWidgets('Space activates the focused rewind control without bubbling', (
      tester,
    ) async {
      var ancestorSpaceCount = 0;
      final scopeNode = FocusScopeNode();
      addTearDown(scopeNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.space) {
                  ancestorSpaceCount++;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusScope(
                node: scopeNode,
                child: Center(child: buildCenterGroup()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 直接请求 Rewind 的焦点，避免测试依赖平台默认 Tab 初始位置。
      final rewindDetector = tester
          .widgetList<FocusableActionDetector>(
            find.byType(FocusableActionDetector),
          )
          .first;
      rewindDetector.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(engine.skipBackCallCount, 1);
      expect(ancestorSpaceCount, 0);
    });

    testWidgets('focused control keeps its hit-test geometry unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));
      await tester.pump();

      final rewind = find.byIcon(Icons.replay_10);
      final rectBeforeFocus = tester.getRect(rewind);
      final detectors = tester
          .widgetList<FocusableActionDetector>(
            find.byType(FocusableActionDetector),
          )
          .toList();
      detectors[1].focusNode!.requestFocus();
      await tester.pump();

      expect(tester.getRect(rewind), rectBeforeFocus);
    });

    testWidgets('buttons expose explicit names and state through semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      // 在测试体内释放，避免测试绑定在验证结束前检测到活动句柄。
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));
      await tester.pump();

      expect(find.bySemanticsLabel('Rewind 10s'), findsOneWidget);
      expect(find.bySemanticsLabel('Forward 30s'), findsOneWidget);
      expect(find.bySemanticsLabel('Stop'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Play')),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('playing control exposes pause with toggled semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      // 在测试体内释放，避免测试绑定在验证结束前检测到活动句柄。
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject(child: buildCenterGroup()));
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Pause')),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
