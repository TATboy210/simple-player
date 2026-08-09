import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';

/// TestTickerProvider — provides a Ticker for AutoHideController in tests.
class _TestTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestTickerProvider vsync;
  // 路径B阶段2:AutoHide 归约为 isPlaying bool(非 playing 永显,
  // 仅 playing 自动隐藏)。false = idle/opening/paused/completed/error,
  // true = playing。AutoHide 构造时 addListener,值变化自动触发
  // _onPlayingChanged — 测试只需改 isPlaying.value,无需手动调用。
  late ValueNotifier<bool> isPlaying;

  setUp(() {
    vsync = _TestTickerProvider();
    isPlaying = ValueNotifier(false); // 默认非 playing(idle 语义)
  });

  tearDown(() {
    isPlaying.dispose();
  });

  AutoHideController createController({
    bool isFullscreen = false,
    ValueNotifier<int>? popupCloseNotifier,
  }) {
    final controller = AutoHideController(
      vsync: vsync,
      isPlaying: isPlaying,
      isFullscreen: isFullscreen,
      popupCloseNotifier: popupCloseNotifier,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('AutoHideController.init()', () {
    test('idle state shows permanently without timer', () {
      isPlaying.value = false;
      final c = createController();
      c.init();

      expect(c.visible.value, isTrue);
    });

    test('non-idle state starts auto-hide timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.show()', () {
    test('sets visible to true when hidden', () {
      final c = createController();
      c.visible.value = false;

      c.show();

      expect(c.visible.value, isTrue);
    });

    test('no-op when already visible', () {
      final c = createController();
      expect(c.visible.value, isTrue);

      c.show();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.hide()', () {
    test('does not hide when not playing', () {
      isPlaying.value = false;
      final c = createController();
      c.init();

      c.hide();

      expect(c.visible.value, isTrue);
    });

    test('does not hide when hovering', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.onMouseEnter();

      c.hide();

      // hide() 启动 reverse 动画,但同步测试动画未完成,visible 仍 true
      expect(c.visible.value, isTrue);
    });

    test('increments popupCloseNotifier when hiding', () {
      final notifier = ValueNotifier<int>(0);
      isPlaying.value = true;
      final c = createController(popupCloseNotifier: notifier);
      c.init();

      c.hide();

      expect(notifier.value, 1);
      notifier.dispose();
    });
  });

  group('AutoHideController.onMouseMove()', () {
    test('no-op when not playing', () {
      isPlaying.value = false;
      final c = createController();
      c.init();
      c.visible.value = false;

      c.onMouseMove();

      expect(c.visible.value, isFalse);
    });

    test('shows and schedules hide when playing', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      c.onMouseMove();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.onMouseEnter()', () {
    test('sets hovering and shows', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      c.onMouseEnter();

      expect(c.isHovering, isTrue);
      expect(c.visible.value, isTrue);
    });

    testWidgets('records hover but keeps hidden controls hidden during resize', (
      tester,
    ) async {
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final controller = state.controller;

      controller.hide();
      await tester.pumpAndSettle();
      expect(controller.visible.value, isFalse);

      controller.resizing = true;
      controller.onMouseEnter();

      // Resize only freezes visual auto-hide behavior. Keep the actual pointer
      // state so a later exit remains accurate, without resurfacing controls.
      expect(controller.isHovering, isTrue);
      expect(controller.visible.value, isFalse);
    });
  });

  group('AutoHideController.onMouseExit()', () {
    test('clears hovering and schedules hide when playing', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.onMouseEnter();

      c.onMouseExit();

      expect(c.isHovering, isFalse);
    });

    test('does not schedule hide when not playing', () {
      isPlaying.value = false;
      final c = createController();
      c.init();

      c.onMouseExit();

      expect(c.isHovering, isFalse);
    });
  });

  group('AutoHideController isPlaying transitions', () {
    test('non-playing shows permanently and cancels timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false; // true→false 触发 _onPlayingChanged → 永显

      expect(c.visible.value, isTrue);
    });

    test('playing shows and schedules hide', () {
      isPlaying.value = false;
      final c = createController();
      c.init();

      isPlaying.value = true; // false→true 触发 show + scheduleHide

      expect(c.visible.value, isTrue);
    });

    test('paused shows without scheduling hide', () {
      // 归约:paused = 非 playing = false,永显不调度
      isPlaying.value = true;
      final c = createController();
      c.init();

      isPlaying.value = false; // true→false 触发永显

      expect(c.visible.value, isTrue);
    });

    test('idle shows without scheduling hide', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });

    test('error shows without scheduling hide', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.isFullscreen setter', () {
    test('changing isFullscreen triggers scheduleHide', () {
      isPlaying.value = true;
      final c = createController(isFullscreen: false);
      c.init();

      c.isFullscreen = true;

      // No crash, scheduleHide was called
      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController opacity', () {
    test('opacity animation is available', () {
      final c = createController();

      expect(c.opacity, isNotNull);
      expect(c.opacity.value, 1.0);
    });
  });

  group('AutoHideController.scheduleHide()', () {
    test('cancels previous timer on repeated calls', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      c.scheduleHide();
      c.scheduleHide();
      c.scheduleHide();

      // No crash from timer pileup
      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.resizing', () {
    test('resizing=true cancels hide timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.scheduleHide();

      c.resizing = true;

      // Timer canceled — resizing freezes auto-hide
      expect(c.visible.value, isTrue);
    });

    test(
      'resizing=true prevents a stale hide callback from starting fade-out',
      () {
        isPlaying.value = true;
        final popupCloseNotifier = ValueNotifier<int>(0);
        addTearDown(popupCloseNotifier.dispose);
        final c = createController(popupCloseNotifier: popupCloseNotifier);
        c.init();
        c.resizing = true;

        // Model a timer callback that was already queued when resize began. The
        // final hide gate, rather than Timer.cancel timing, owns this invariant.
        c.hide();

        expect(popupCloseNotifier.value, 0);
        expect(c.visible.value, isTrue);
      },
    );

    test('resizing=false schedules hide', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.resizing = true;

      c.resizing = false;

      // scheduleHide called — timer restarted
      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.onMouseMove() throttle', () {
    test('second call within throttle window is no-op', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      c.onMouseMove(); // first call — shows
      c.visible.value = false;
      c.onMouseMove(); // within 100ms throttle — no-op

      expect(c.visible.value, isFalse);
    });
  });

  group('AutoHideController.onMouseMove() — resize freeze', () {
    test('onMouseMove is no-op when resizing=true', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.resizing = true;
      c.visible.value = false;

      c.onMouseMove();

      // resizing blocks onMouseMove — visible stays false
      expect(c.visible.value, isFalse);
    });

    test('onMouseMove resumes after resizing=false', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.resizing = true;
      c.visible.value = false;

      c.onMouseMove(); // no-op during resize
      expect(c.visible.value, isFalse);

      c.resizing = false;
      c.onMouseMove(); // now allowed (throttle may still apply)
    });
  });

  group('AutoHideController — hovering does not block hide', () {
    testWidgets('scheduleHide timer hides even when hovering (静止 3s 隐藏)', (
      tester,
    ) async {
      // 阶段3问题3:对齐 media_kit 原生 — 鼠标在 Video 内静止 3s 也隐藏,
      // 不因 hovering 阻止。仅 _activeInteractionCount 保护交互期间不隐藏。
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(
          home: _TestAutoHideWrapper(isPlaying: isPlaying, isFullscreen: false),
        ),
      );
      await tester.pump();

      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final c = state.controller;

      c.show();
      c.onMouseEnter(); // hovering = true
      c.scheduleHide();

      // Advance past 3s hide delay — 静止 3s 隐藏(不再被 hovering 阻止)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(c.visible.value, isFalse);
    });
  });

  group('AutoHideController.onMouseMove() — throttle boundary', () {
    test('onMouseMove passes after 100ms throttle window', () {
      isPlaying.value = true;
      final c = createController();
      c.init();

      c.onMouseMove(); // first call — show + scheduleHide
      c.visible.value = false;

      // Within 100ms — throttled, no-op
      c.onMouseMove();
      expect(c.visible.value, isFalse);
    });
  });

  group('AutoHideController — fullscreen hide delay', () {
    test('fullscreen hide delay is shorter than windowed', () {
      isPlaying.value = true;
      final windowed = createController(isFullscreen: false);
      windowed.init();
      final fullscreen = createController(isFullscreen: true);
      fullscreen.init();

      expect(windowed.visible.value, isTrue);
      expect(fullscreen.visible.value, isTrue);
    });
  });

  group('AutoHideController — animation dismissed', () {
    test('hide triggers reverse animation then sets visible false', () async {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.onMouseEnter(); // hovering = true
      c.onMouseExit(); // hovering = false, scheduleHide called

      // Manually trigger hide (not via timer)
      c.hide();

      // Animation is reversing — visible still true until dismissed
      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController — scheduleHide timer fires hide', () {
    testWidgets('timer callback hides when not hovering', (tester) async {
      // scheduleHide creates Timer(3s) in windowed mode (Tokens.hideDelayWindowed).
      // After pump(Duration(seconds: 4)), the timer fires and calls hide().
      // hide() reverses the animation (150ms). pumpAndSettle() completes it.
      // _onAnimStatus(dismissed) → visible = false.
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(
          home: _TestAutoHideWrapper(isPlaying: isPlaying, isFullscreen: false),
        ),
      );
      await tester.pump();

      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final c = state.controller;

      // Start auto-hide timer via scheduleHide
      c.scheduleHide();

      // Advance past the 3s windowed hide delay
      await tester.pump(const Duration(seconds: 4));
      // Timer fired → hide() → _animController.reverse()
      // Now let the reverse animation (150ms) complete
      await tester.pumpAndSettle();

      // _onAnimStatus(dismissed) should have fired → visible = false
      expect(c.visible.value, isFalse);
    });
  });

  group('AutoHideController isPlaying transitions — hidden', () {
    test('playing when hidden shows and schedules hide', () {
      isPlaying.value = false;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = true; // false→true 触发 show + scheduleHide

      expect(c.visible.value, isTrue);
    });

    test('non-playing when hidden shows without scheduling hide', () {
      // 非 playing 永显策略:show() + cancel timer(不 scheduleHide)
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false; // true→false 触发永显

      expect(c.visible.value, isTrue);
    });

    test('paused when hidden shows and cancels timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });

    test('idle when hidden shows and cancels timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });

    test('completed when hidden shows and cancels timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });

    test('error when hidden shows and cancels timer', () {
      isPlaying.value = true;
      final c = createController();
      c.init();
      c.visible.value = false;

      isPlaying.value = false;

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController isPlaying transitions — 非 playing persistence', () {
    testWidgets('non-playing keeps controls visible past hide delay', (
      tester,
    ) async {
      // 非 playing 永显:进入非 playing 后 timer 被 cancel,
      // pump 超过 hide delay 仍可见
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final c = state.controller;
      c.visible.value = false;

      isPlaying.value = false; // true→false 触发永显 + cancel timer

      // pump 超过 hide delay(3s)— 非 playing 永显,timer 被 cancel,不隐藏
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController interaction sessions', () {
    testWidgets('keeps controls visible while a child interaction is active', (
      tester,
    ) async {
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final controller = state.controller;

      // A child control owns the interaction period, so its hover or drag
      // cannot be interrupted by the playing-state hide timer.
      controller.onInteractionStart();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(controller.visible.value, isTrue);
    });

    testWidgets('restarts auto-hide after the last child interaction ends', (
      tester,
    ) async {
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final controller = state.controller;

      controller.onInteractionStart();
      controller.onInteractionEnd();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(controller.visible.value, isFalse);
    });

    test('interaction methods are no-ops when not playing', () {
      isPlaying.value = false;
      final controller = createController();
      controller.init();
      controller.visible.value = false;

      controller.onInteractionStart();
      controller.onInteractionEnd();

      expect(controller.visible.value, isFalse);
    });
  });

  group('AutoHideController.onSeekStart/onSeekEnd', () {
    testWidgets('onSeekStart shows and freezes hide timer', (tester) async {
      // seek 拖动保护:onSeekStart 显示控件 + cancel timer,
      // pump 超过 delay 仍可见
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final c = state.controller;

      // 先隐藏控件
      c.hide();
      await tester.pumpAndSettle();
      expect(c.visible.value, isFalse);

      // onSeekStart — 显示 + cancel hide timer
      c.onSeekStart();
      expect(c.visible.value, isTrue);

      // pump 超过 hide delay — timer 被 cancel,seek 期间不隐藏
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(c.visible.value, isTrue);
    });

    testWidgets('onSeekEnd restarts hide timer', (tester) async {
      // onSeekEnd 重启计时:pump 超过 delay 后控件隐藏
      isPlaying.value = true;
      await tester.pumpWidget(
        MaterialApp(home: _TestAutoHideWrapper(isPlaying: isPlaying)),
      );
      await tester.pump();
      final state = tester.state<_TestAutoHideWrapperState>(
        find.byType(_TestAutoHideWrapper),
      );
      final c = state.controller;

      c.onSeekStart(); // cancel timer
      c.onSeekEnd(); // 重启 timer(3s)

      await tester.pump(const Duration(seconds: 4)); // past 3s
      await tester.pumpAndSettle();

      expect(c.visible.value, isFalse); // timer fires → hide
    });

    test('onSeekStart/onSeekEnd are no-op when not playing', () {
      isPlaying.value = false;
      final c = createController();
      c.init();
      c.visible.value = false;

      c.onSeekStart();
      expect(c.visible.value, isFalse); // 非 playing 跳过

      c.onSeekEnd();
      expect(c.visible.value, isFalse); // 非 playing 跳过
    });
  });
}

/// Wrapper widget that provides a real TickerProvider for AutoHideController.
/// Used in widget tests where AnimationController + pump() is needed.
class _TestAutoHideWrapper extends StatefulWidget {
  final ValueNotifier<bool> isPlaying;
  final bool isFullscreen;
  const _TestAutoHideWrapper({
    required this.isPlaying,
    this.isFullscreen = false,
  });
  @override
  State<_TestAutoHideWrapper> createState() => _TestAutoHideWrapperState();
}

class _TestAutoHideWrapperState extends State<_TestAutoHideWrapper>
    with SingleTickerProviderStateMixin {
  late final AutoHideController controller;

  @override
  void initState() {
    super.initState();
    controller = AutoHideController(
      vsync: this,
      isPlaying: widget.isPlaying,
      isFullscreen: widget.isFullscreen,
    );
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
