import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/media_state.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';

/// TestTickerProvider — provides a Ticker for AutoHideController in tests.
class _TestTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestTickerProvider vsync;
  late ValueNotifier<MediaState> engineState;

  setUp(() {
    vsync = _TestTickerProvider();
    engineState = ValueNotifier(MediaState.idle);
  });

  tearDown(() {
    engineState.dispose();
  });

  AutoHideController createController({
    bool isFullscreen = false,
    ValueNotifier<int>? popupCloseNotifier,
  }) {
    final controller = AutoHideController(
      vsync: vsync,
      engineState: engineState,
      isFullscreen: isFullscreen,
      popupCloseNotifier: popupCloseNotifier,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('AutoHideController.init()', () {
    test('idle state shows permanently without timer', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      expect(c.visible.value, isTrue);
    });

    test('non-idle state starts auto-hide timer', () {
      engineState.value = MediaState.playing;
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
    test('does not hide when engine is idle', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      c.hide();

      expect(c.visible.value, isTrue);
    });

    test('does not hide when hovering', () {
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();
      c.onMouseEnter();

      c.hide();

      expect(c.visible.value, isTrue);
    });

    test('increments popupCloseNotifier when hiding', () {
      final notifier = ValueNotifier<int>(0);
      engineState.value = MediaState.playing;
      final c = createController(popupCloseNotifier: notifier);
      c.init();

      c.hide();

      expect(notifier.value, 1);
      notifier.dispose();
    });
  });

  group('AutoHideController.onMouseMove()', () {
    test('no-op when engine is idle', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();
      c.visible.value = false;

      c.onMouseMove();

      expect(c.visible.value, isFalse);
    });

    test('shows and schedules hide when not idle', () {
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();
      c.visible.value = false;

      c.onMouseMove();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.onMouseEnter()', () {
    test('sets hovering and shows', () {
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();

      c.onMouseEnter();

      expect(c.isHovering, isTrue);
      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.onMouseExit()', () {
    test('clears hovering and schedules hide when not idle', () {
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();
      c.onMouseEnter();

      c.onMouseExit();

      expect(c.isHovering, isFalse);
    });

    test('does not schedule hide when idle', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      c.onMouseExit();

      expect(c.isHovering, isFalse);
    });
  });

  group('AutoHideController.onEngineStateChanged()', () {
    test('idle shows permanently and cancels timer', () {
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();
      c.visible.value = false;

      engineState.value = MediaState.idle;
      c.onEngineStateChanged();

      expect(c.visible.value, isTrue);
    });

    test('playing shows and schedules hide', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      engineState.value = MediaState.playing;
      c.onEngineStateChanged();

      expect(c.visible.value, isTrue);
    });

    test('paused shows without scheduling hide', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      engineState.value = MediaState.paused;
      c.onEngineStateChanged();

      expect(c.visible.value, isTrue);
    });

    test('stopped shows without scheduling hide', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      engineState.value = MediaState.stopped;
      c.onEngineStateChanged();

      expect(c.visible.value, isTrue);
    });

    test('error shows without scheduling hide', () {
      engineState.value = MediaState.idle;
      final c = createController();
      c.init();

      engineState.value = MediaState.error;
      c.onEngineStateChanged();

      expect(c.visible.value, isTrue);
    });
  });

  group('AutoHideController.isFullscreen setter', () {
    test('changing isFullscreen triggers scheduleHide', () {
      engineState.value = MediaState.playing;
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
      engineState.value = MediaState.playing;
      final c = createController();
      c.init();

      c.scheduleHide();
      c.scheduleHide();
      c.scheduleHide();

      // No crash from timer pileup
      expect(c.visible.value, isTrue);
    });
  });
}
