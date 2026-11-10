import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/service/normal_bounds_tracker.dart';

import '../../../helpers/fake_native_window.dart';

void main() {
  late FakeNativeWindow window;
  late bool canTrack;
  late NormalBoundsTracker tracker;

  setUp(() {
    window = FakeNativeWindow();
    canTrack = true;
    tracker = NormalBoundsTracker(
      window: () => window,
      canTrack: () => canTrack,
    );
    addTearDown(tracker.dispose);
  });

  group('noteChanged', () {
    test('samples immediately on the first event', () {
      window.boundsValue = const Rect.fromLTWH(10, 20, 900, 500);

      tracker.noteChanged();

      expect(tracker.value, const Rect.fromLTWH(10, 20, 900, 500));
    });

    test('coalesces a burst into one leading and one trailing read', () {
      fakeAsync((async) {
        for (var i = 0; i < 40; i++) {
          window.boundsValue = Rect.fromLTWH(0, 0, 800.0 + i, 500);
          tracker.noteChanged();
          async.elapse(const Duration(milliseconds: 2));
        }
        // 冷却期（120ms）内 40 个事件（共 80ms）: 首沿 1 次，尾沿尚未到期。
        expect(window.boundsReads, 1);

        async.elapse(const Duration(milliseconds: 200));

        expect(window.boundsReads, 2);
        // 尾沿采到的是最新矩形。
        expect(tracker.value.width, 839);
      });
    });

    test('does not schedule a trailing read when nothing changed after', () {
      fakeAsync((async) {
        tracker.noteChanged();
        async.elapse(const Duration(seconds: 1));

        expect(window.boundsReads, 1);
      });
    });
  });

  group('sample', () {
    test('skips maximized, minimized and untrackable states', () {
      tracker.value = const Rect.fromLTWH(1, 2, 3, 4);

      window
        ..maximized = true
        ..boundsValue = const Rect.fromLTWH(0, 0, 1920, 1040);
      tracker.sample();
      expect(tracker.value, const Rect.fromLTWH(1, 2, 3, 4));

      window
        ..maximized = false
        ..minimized = true
        ..boundsValue = const Rect.fromLTWH(-32000, -32000, 160, 28);
      tracker.sample();
      expect(tracker.value, const Rect.fromLTWH(1, 2, 3, 4));

      window
        ..minimized = false
        ..boundsValue = const Rect.fromLTWH(5, 5, 500, 300);
      canTrack = false;
      tracker.sample();
      expect(tracker.value, const Rect.fromLTWH(1, 2, 3, 4));
    });

    test('ignores an all-zero rect from a failed native read', () {
      tracker.value = const Rect.fromLTWH(1, 2, 3, 4);
      window.boundsValue = Rect.zero;

      tracker.sample();

      expect(tracker.value, const Rect.fromLTWH(1, 2, 3, 4));
    });
  });
}
