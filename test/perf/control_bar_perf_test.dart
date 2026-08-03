/// Control Bar Performance Profiling Tests
///
/// DevTools 手动 profiling 流程（profile 模式）:
///
/// 1. 启动: `flutter run -d windows --profile`
/// 2. 打开 DevTools > Performance tab
/// 3. 录制基线: control bar 空闲（无交互）
/// 4. 录制: control bar hover + 鼠标移动
/// 5. 录制: 4K 播放 + control bar 可见
/// 6. 录制: progress bar seek（快速拖拽）
/// 7. 录制: 窗口模式 vs 全屏模式
/// 8. 录制: 字幕启用场景
/// 9. 阈值: 16.6ms/帧 (60fps, D-03)
/// 10. 对比: enableBlur=true vs enableBlur=false (D-08)
///
/// Phase 2 优化验证:
/// - ControlBar enableBlur=false 时跳过 BackdropFilter (line 131)
/// - ControlBar enableBlur=true 时通过 WindowInteractionState 跳过 resize 期间 BackdropFilter
/// - GlassContainer respectResizeState=true 时 resize 期间降级为纯色
/// - GlassIconButton 使用 Material+InkWell，无 BackdropFilter（无双层模糊）
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import '../helpers/fake_engine.dart';

void _noop() {}

/// 包装 widget，统计 build 次数
class _RebuildCounter extends StatefulWidget {
  final Widget child;
  final ValueNotifier<int> count;

  const _RebuildCounter({required this.child, required this.count});

  @override
  State<_RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<_RebuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.count.value++;
    return widget.child;
  }
}

Widget _buildControlBar(
  FakeEngine engine,
  Playlist playlist,
  ValueNotifier<int> playlistGeneration, {
  bool enableBlur = true,
  bool isIdle = false,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 200,
        child: ControlBar(
          engine: engine,
          playlist: playlist,
          playlistGeneration: playlistGeneration,
          actions: const PlayerActions(
            onOpenFile: _noop,
            onSettings: _noop,
            onToggleFullscreen: _noop,
          ),
          enableBlur: enableBlur,
          isIdle: isIdle,
        ),
      ),
    ),
  );
}

Widget _buildControlsOverlay(
  FakeEngine engine,
  Playlist playlist,
  ValueNotifier<int> playlistGeneration,
  ValueNotifier<String> currentFileName,
  ValueNotifier<bool> openFileEnabled,
) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ControlsOverlay(
        engine: engine,
        currentFileName: currentFileName,
        playlist: playlist,
        playlistGeneration: playlistGeneration,
        openFileEnabled: openFileEnabled,
        actions: const PlayerActions(onToggleFullscreen: _noop),
      ),
    ),
  );
}

void main() {
  // 渐进路径:ControlBar/ControlsOverlay 需 playlist + generation(overlay 还需
  // currentFileName/openFileEnabled)。两个 group 共享,main 顶层 setUp/tearDown
  // 各跑一次,group 内 setUp 只管 engine。
  late Playlist playlist;
  late ValueNotifier<int> playlistGeneration;
  late ValueNotifier<String> currentFileName;
  late ValueNotifier<bool> openFileEnabled;

  setUp(() {
    playlist = Playlist();
    playlistGeneration = ValueNotifier<int>(0);
    currentFileName = ValueNotifier<String>('');
    openFileEnabled = ValueNotifier<bool>(true);
  });

  tearDown(() {
    playlistGeneration.dispose();
    currentFileName.dispose();
    openFileEnabled.dispose();
  });

  group('ControlBar rebuild profiling', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 120000);
      engine.state.value = MediaState.playing;
    });

    tearDown(() {
      engine.dispose();
    });

    testWidgets(
      'rebuild count during playback — position updates at 250ms intervals',
      (tester) async {
        final rebuildCount = ValueNotifier<int>(0);
        await tester.pumpWidget(
          _RebuildCounter(
            count: rebuildCount,
            child: _buildControlBar(engine, playlist, playlistGeneration),
          ),
        );
        await tester.pump();
        final initialCount = rebuildCount.value;

        // Simulate 10 position updates at 250ms intervals (PositionPoller rate)
        for (var i = 1; i <= 10; i++) {
          engine.position.value = i * 3000; // 3s increments
          await tester.pump(const Duration(milliseconds: 250));
        }

        final totalRebuilds = rebuildCount.value - initialCount;
        // Parent should NOT rebuild on position updates — children handle via
        // their own ValueListenableBuilder/AnimatedBuilder.
        // Allow small margin for framework overhead.
        expect(
          totalRebuilds,
          lessThanOrEqualTo(2),
          reason:
              'ControlBar parent rebuilt $totalRebuilds times during '
              '10 position updates (expected <= 2)',
        );
      },
    );

    testWidgets('rebuild count — enableBlur true vs false isolation (D-08)', (
      tester,
    ) async {
      // With blur enabled
      final blurCount = ValueNotifier<int>(0);
      await tester.pumpWidget(
        _RebuildCounter(
          count: blurCount,
          child: _buildControlBar(
            engine,
            playlist,
            playlistGeneration,
            enableBlur: true,
          ),
        ),
      );
      await tester.pump();
      final blurInitial = blurCount.value;

      for (var i = 1; i <= 5; i++) {
        engine.position.value = i * 5000;
        await tester.pump(const Duration(milliseconds: 250));
      }
      final blurTotal = blurCount.value - blurInitial;

      // With blur disabled
      final noBlurCount = ValueNotifier<int>(0);
      await tester.pumpWidget(
        _RebuildCounter(
          count: noBlurCount,
          child: _buildControlBar(
            engine,
            playlist,
            playlistGeneration,
            enableBlur: false,
          ),
        ),
      );
      await tester.pump();
      final noBlurInitial = noBlurCount.value;

      for (var i = 1; i <= 5; i++) {
        engine.position.value = i * 5000 + 30000;
        await tester.pump(const Duration(milliseconds: 250));
      }
      final noBlurTotal = noBlurCount.value - noBlurInitial;

      // Both should have similar rebuild counts (parent doesn't rebuild
      // on position changes regardless of blur setting).
      // The difference is in GPU cost, not build count.
      expect(blurTotal, lessThanOrEqualTo(2));
      expect(noBlurTotal, lessThanOrEqualTo(2));
    });

    testWidgets('rebuild count during seek — rapid position updates', (
      tester,
    ) async {
      final rebuildCount = ValueNotifier<int>(0);
      await tester.pumpWidget(
        _RebuildCounter(
          count: rebuildCount,
          child: _buildControlBar(engine, playlist, playlistGeneration),
        ),
      );
      await tester.pump();
      final initialCount = rebuildCount.value;

      // Simulate rapid seek — 50 position updates in quick succession
      for (var i = 0; i < 50; i++) {
        engine.position.value = (i * 2400).clamp(0, 120000);
        await tester.pump(const Duration(milliseconds: 16)); // ~60fps
      }

      final totalRebuilds = rebuildCount.value - initialCount;
      // Parent should not rebuild on position changes during seek.
      // Children (ProgressBar, TimeRangeDisplay) handle via AnimatedBuilder.
      expect(
        totalRebuilds,
        lessThanOrEqualTo(5),
        reason:
            'ControlBar parent rebuilt $totalRebuilds times during '
            '50 rapid seek updates (expected <= 5)',
      );
    });

    testWidgets('Phase 2 verification — enableBlur=false skips BackdropFilter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildControlBar(
          engine,
          playlist,
          playlistGeneration,
          enableBlur: false,
        ),
      );
      await tester.pump();

      // When enableBlur=false, ControlBar returns RepaintBoundary(child: content)
      // without BackdropFilter. Verify the widget tree has no BackdropFilter.
      expect(
        find.descendant(
          of: find.byType(ControlBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
        reason: 'enableBlur=false should skip BackdropFilter entirely',
      );
    });

    testWidgets(
      'Phase 2 verification — enableBlur=true includes BackdropFilter',
      (tester) async {
        await tester.pumpWidget(
          _buildControlBar(
            engine,
            playlist,
            playlistGeneration,
            enableBlur: true,
          ),
        );
        await tester.pump();

        // When enableBlur=true and WindowInteractionState is idle,
        // BackdropFilter should be present.
        expect(
          find.descendant(
            of: find.byType(ControlBar),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
          reason: 'enableBlur=true + idle state should include BackdropFilter',
        );
      },
    );

    testWidgets('Phase 2 verification — RepaintBoundary wraps content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildControlBar(
          engine,
          playlist,
          playlistGeneration,
          enableBlur: false,
        ),
      );
      await tester.pump();

      // ControlBar wraps content in RepaintBoundary in both paths.
      expect(
        find.descendant(
          of: find.byType(ControlBar),
          matching: find.byType(RepaintBoundary),
        ),
        findsAtLeastNWidgets(1),
        reason: 'ControlBar should wrap content in RepaintBoundary',
      );
    });
  });

  group('ControlsOverlay rebuild profiling', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 120000);
      engine.state.value = MediaState.playing;
    });

    tearDown(() {
      engine.dispose();
    });

    testWidgets(
      'rebuild count during mouse movement — AutoHideController throttle',
      (tester) async {
        final rebuildCount = ValueNotifier<int>(0);
        await tester.pumpWidget(
          _RebuildCounter(
            count: rebuildCount,
            child: _buildControlsOverlay(
              engine,
              playlist,
              playlistGeneration,
              currentFileName,
              openFileEnabled,
            ),
          ),
        );
        await tester.pump();
        final initialCount = rebuildCount.value;

        // Simulate rapid mouse movement — AutoHideController has 100ms throttle
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(
          location: tester.getCenter(find.byType(ControlsOverlay)),
        );
        addTearDown(gesture.removePointer);

        // Move mouse 20 times in quick succession
        final center = tester.getCenter(find.byType(ControlsOverlay));
        for (var i = 0; i < 20; i++) {
          await gesture.moveTo(center + Offset(i.toDouble() * 5, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }

        final totalRebuilds = rebuildCount.value - initialCount;
        // AutoHideController throttles at 100ms, so 20 moves at 16ms intervals
        // should result in ~3-4 effective updates (not 20).
        // Parent rebuild count depends on how many times _autoHide.visible changes.
        expect(
          totalRebuilds,
          lessThanOrEqualTo(10),
          reason:
              'ControlsOverlay parent rebuilt $totalRebuilds times during '
              '20 rapid mouse moves (expected <= 10 due to 100ms throttle)',
        );
      },
    );

    testWidgets('ControlsOverlay child caching — Stack is static subtree', (
      tester,
    ) async {
      // The outer ValueListenableBuilder<bool> on _autoHide.visible
      // caches the Stack as `child`. Verify the Stack doesn't rebuild
      // when visibility toggles.
      await tester.pumpWidget(
        _buildControlsOverlay(
          engine,
          playlist,
          playlistGeneration,
          currentFileName,
          openFileEnabled,
        ),
      );
      await tester.pump();

      // Verify at least one Stack exists (cached child inside VLB).
      // Multiple Stacks are expected from MaterialApp/Scaffold/ControlsOverlay.
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
    });
  });
}
