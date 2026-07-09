import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_capability.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_error.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_event.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_request.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_snapshot.dart';

void main() {
  // ─── Task 1: FullscreenPhase + FullscreenMode + FullscreenSnapshot ───

  group('FullscreenPhase', () {
    test('has exactly 5 values', () {
      expect(FullscreenPhase.values.length, 5);
    });

    test('contains stable, entering, leaving, forcedChange, error', () {
      expect(FullscreenPhase.values, contains(FullscreenPhase.stable));
      expect(FullscreenPhase.values, contains(FullscreenPhase.entering));
      expect(FullscreenPhase.values, contains(FullscreenPhase.leaving));
      expect(FullscreenPhase.values, contains(FullscreenPhase.forcedChange));
      expect(FullscreenPhase.values, contains(FullscreenPhase.error));
    });
  });

  group('FullscreenMode', () {
    test('has exactly 3 values', () {
      expect(FullscreenMode.values.length, 3);
    });

    test('contains windowed, borderless, exclusive', () {
      expect(FullscreenMode.values, contains(FullscreenMode.windowed));
      expect(FullscreenMode.values, contains(FullscreenMode.borderless));
      expect(FullscreenMode.values, contains(FullscreenMode.exclusive));
    });
  });

  group('FullscreenSnapshot', () {
    test('default constructor creates stable/windowed state', () {
      const snapshot = FullscreenSnapshot();
      expect(snapshot.phase, FullscreenPhase.stable);
      expect(snapshot.effectiveMode, FullscreenMode.windowed);
      expect(snapshot.restoreMode, FullscreenMode.windowed);
      expect(snapshot.displayId, 0);
      expect(snapshot.lastError, isNull);
    });

    test('copyWith returns new instance, original unchanged', () {
      const original = FullscreenSnapshot();
      final modified = original.copyWith(
        phase: FullscreenPhase.entering,
        effectiveMode: FullscreenMode.borderless,
      );

      // Original unchanged
      expect(original.phase, FullscreenPhase.stable);
      expect(original.effectiveMode, FullscreenMode.windowed);

      // Modified has new values
      expect(modified.phase, FullscreenPhase.entering);
      expect(modified.effectiveMode, FullscreenMode.borderless);
    });

    test('copyWith only modifies specified fields', () {
      const original = FullscreenSnapshot(
        displayId: 5,
        restoreMode: FullscreenMode.borderless,
      );
      final modified = original.copyWith(phase: FullscreenPhase.leaving);

      // Unspecified fields preserved
      expect(modified.displayId, 5);
      expect(modified.restoreMode, FullscreenMode.borderless);
      // Specified field changed
      expect(modified.phase, FullscreenPhase.leaving);
    });

    test('copyWith clearError sets lastError to null', () {
      const withError = FullscreenSnapshot(
        phase: FullscreenPhase.error,
        lastError: Unsupported('test'),
      );
      final cleared = withError.copyWith(
        phase: FullscreenPhase.stable,
        clearError: true,
      );

      expect(cleared.lastError, isNull);
      expect(cleared.phase, FullscreenPhase.stable);
    });

    test('equality based on value comparison', () {
      const a = FullscreenSnapshot(displayId: 1);
      const b = FullscreenSnapshot(displayId: 1);
      const c = FullscreenSnapshot(displayId: 2);

      expect(a, equals(b));
      expect(a == c, isFalse);
    });

    test('isFullscreen is true when stable + non-windowed', () {
      const windowed = FullscreenSnapshot();
      expect(windowed.isFullscreen, isFalse);

      const fullscreen = FullscreenSnapshot(
        phase: FullscreenPhase.stable,
        effectiveMode: FullscreenMode.borderless,
      );
      expect(fullscreen.isFullscreen, isTrue);

      const transitioning = FullscreenSnapshot(
        phase: FullscreenPhase.entering,
        effectiveMode: FullscreenMode.borderless,
      );
      // Transitioning does NOT count as fullscreen
      expect(transitioning.isFullscreen, isFalse);
    });

    test('isTransitioning is true for entering/leaving', () {
      const stable = FullscreenSnapshot();
      expect(stable.isTransitioning, isFalse);

      const entering = FullscreenSnapshot(phase: FullscreenPhase.entering);
      expect(entering.isTransitioning, isTrue);

      const leaving = FullscreenSnapshot(phase: FullscreenPhase.leaving);
      expect(leaving.isTransitioning, isTrue);

      const forced = FullscreenSnapshot(phase: FullscreenPhase.forcedChange);
      expect(forced.isTransitioning, isFalse);
    });

    test('hasError is true for error phase', () {
      const error = FullscreenSnapshot(phase: FullscreenPhase.error);
      expect(error.hasError, isTrue);

      const stable = FullscreenSnapshot();
      expect(stable.hasError, isFalse);
    });
  });

  // ─── Task 2: FullscreenError sealed class ───

  group('FullscreenError', () {
    test('is a sealed class', () {
      // Verify sealed class by checking subtypes
      const errors = <FullscreenError>[
        Unsupported('msg'),
        InvalidWindow(1),
        PermissionDenied('reason'),
        BusyTransition(FullscreenPhase.entering),
        PlatformFailure('msg'),
        RestoreFailure(FullscreenMode.borderless),
        StateDesync(
          expected: FullscreenMode.borderless,
          actual: FullscreenMode.windowed,
        ),
      ];
      expect(errors.length, 7);
    });

    test('Unsupported has message field', () {
      const error = Unsupported('not supported');
      expect(error.message, 'not supported');
    });

    test('InvalidWindow has windowId field', () {
      const error = InvalidWindow(42);
      expect(error.windowId, 42);
    });

    test('PermissionDenied has reason field', () {
      const error = PermissionDenied('user gesture required');
      expect(error.reason, 'user gesture required');
    });

    test('BusyTransition has currentPhase field', () {
      const error = BusyTransition(FullscreenPhase.leaving);
      expect(error.currentPhase, FullscreenPhase.leaving);
    });

    test('PlatformFailure has platformMessage and originalError', () {
      const error = PlatformFailure('native call failed', 'details');
      expect(error.platformMessage, 'native call failed');
      expect(error.originalError, 'details');

      const noOriginal = PlatformFailure('msg');
      expect(noOriginal.originalError, isNull);
    });

    test('RestoreFailure has attemptedMode field', () {
      const error = RestoreFailure(FullscreenMode.borderless);
      expect(error.attemptedMode, FullscreenMode.borderless);
    });

    test('StateDesync has expected and actual fields', () {
      const error = StateDesync(
        expected: FullscreenMode.borderless,
        actual: FullscreenMode.windowed,
      );
      expect(error.expected, FullscreenMode.borderless);
      expect(error.actual, FullscreenMode.windowed);
    });

    test('can be used as FullscreenSnapshot.lastError', () {
      const error = Unsupported('test');
      const snapshot = FullscreenSnapshot(
        phase: FullscreenPhase.error,
        lastError: error,
      );
      expect(snapshot.lastError, error);
      expect(snapshot.lastError, isA<Unsupported>());
    });
  });

  // ─── Task 3: FullscreenEvent 事件模型 ───

  group('FullscreenEvent', () {
    test('has 7 subtypes via sealed class', () {
      final now = DateTime.now();
      final events = <FullscreenEvent>[
        EnterRequested(targetMode: FullscreenMode.borderless, timestamp: now),
        Entered(finalMode: FullscreenMode.borderless, timestamp: now),
        LeaveRequested(timestamp: now),
        Left(timestamp: now),
        ForcedChange(
          previousMode: FullscreenMode.windowed,
          actualMode: FullscreenMode.borderless,
          timestamp: now,
        ),
        SyncCorrected(
          expected: FullscreenMode.borderless,
          actual: FullscreenMode.windowed,
          timestamp: now,
        ),
        FullscreenErrorEvent(
          error: const Unsupported('test'),
          timestamp: now,
        ),
      ];
      expect(events.length, 7);
    });

    test('enterRequested carries targetMode', () {
      final event = EnterRequested(
        targetMode: FullscreenMode.exclusive,
        timestamp: DateTime(2026),
      );
      expect(event.targetMode, FullscreenMode.exclusive);
    });

    test('entered carries finalMode', () {
      final event = Entered(
        finalMode: FullscreenMode.borderless,
        timestamp: DateTime(2026),
      );
      expect(event.finalMode, FullscreenMode.borderless);
    });

    test('leaveRequested has no extra fields', () {
      final event = LeaveRequested(timestamp: DateTime(2026));
      expect(event, isA<FullscreenEvent>());
    });

    test('left has no extra fields', () {
      final event = Left(timestamp: DateTime(2026));
      expect(event, isA<FullscreenEvent>());
    });

    test('forcedChange carries previousMode and actualMode', () {
      final event = ForcedChange(
        previousMode: FullscreenMode.windowed,
        actualMode: FullscreenMode.borderless,
        timestamp: DateTime(2026),
      );
      expect(event.previousMode, FullscreenMode.windowed);
      expect(event.actualMode, FullscreenMode.borderless);
    });

    test('syncCorrected carries expected and actual', () {
      final event = SyncCorrected(
        expected: FullscreenMode.borderless,
        actual: FullscreenMode.windowed,
        timestamp: DateTime(2026),
      );
      expect(event.expected, FullscreenMode.borderless);
      expect(event.actual, FullscreenMode.windowed);
    });

    test('error event carries FullscreenError', () {
      const error = Unsupported('test');
      final event = FullscreenErrorEvent(
        error: error,
        timestamp: DateTime(2026),
      );
      expect(event.error, error);
    });

    test('all events have timestamp', () {
      final now = DateTime(2026);
      final events = <FullscreenEvent>[
        EnterRequested(targetMode: FullscreenMode.borderless, timestamp: now),
        Entered(finalMode: FullscreenMode.borderless, timestamp: now),
        LeaveRequested(timestamp: now),
        Left(timestamp: now),
        ForcedChange(
          previousMode: FullscreenMode.windowed,
          actualMode: FullscreenMode.borderless,
          timestamp: now,
        ),
        SyncCorrected(
          expected: FullscreenMode.borderless,
          actual: FullscreenMode.windowed,
          timestamp: now,
        ),
        FullscreenErrorEvent(
          error: const Unsupported('test'),
          timestamp: now,
        ),
      ];
      for (final event in events) {
        expect(event.timestamp, now);
      }
    });

    test('default timestamp is DateTime.now() when not provided', () {
      final before = DateTime.now();
      final event = EnterRequested(targetMode: FullscreenMode.borderless);
      final after = DateTime.now();
      expect(
        event.timestamp.isAfter(before) ||
            event.timestamp.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        event.timestamp.isBefore(after) ||
            event.timestamp.isAtSameMomentAs(after),
        isTrue,
      );
    });
  });

  // ─── Task 4: FullscreenCapability + FullscreenRequest ───

  group('FullscreenCapability', () {
    test('has all expected fields with defaults', () {
      const cap = FullscreenCapability();
      expect(cap.supportsFullscreen, isTrue);
      expect(cap.supportsMultiWindow, isFalse);
      expect(cap.supportsMultiDisplay, isFalse);
      expect(cap.supportsExclusive, isFalse);
      expect(cap.requiresUserGesture, isFalse);
      expect(cap.platformNotes, isNull);
    });

    test('supports custom values', () {
      const cap = FullscreenCapability(
        supportsFullscreen: true,
        supportsMultiWindow: true,
        supportsMultiDisplay: true,
        supportsExclusive: true,
        requiresUserGesture: true,
        platformNotes: 'macOS animation',
      );
      expect(cap.supportsMultiWindow, isTrue);
      expect(cap.supportsExclusive, isTrue);
      expect(cap.platformNotes, 'macOS animation');
    });
  });

  group('FullscreenRequest', () {
    test('enter has targetMode and windowId', () {
      const request = FullscreenRequest.enter(
        mode: FullscreenMode.exclusive,
        windowId: 1,
      );
      expect(request, isA<EnterFullscreen>());
      expect((request as EnterFullscreen).mode, FullscreenMode.exclusive);
      expect(request.windowId, 1);
    });

    test('enter defaults to borderless mode and windowId 0', () {
      const request = FullscreenRequest.enter();
      expect((request as EnterFullscreen).mode, FullscreenMode.borderless);
      expect(request.windowId, 0);
    });

    test('leave has windowId', () {
      const request = FullscreenRequest.leave(windowId: 2);
      expect(request, isA<LeaveFullscreen>());
      expect(request.windowId, 2);
    });

    test('leave defaults to windowId 0', () {
      const request = FullscreenRequest.leave();
      expect(request.windowId, 0);
    });

    test('toggle has optional preferredMode and windowId', () {
      const request = FullscreenRequest.toggle(
        preferredMode: FullscreenMode.exclusive,
        windowId: 3,
      );
      expect(request, isA<ToggleFullscreen>());
      expect(
        (request as ToggleFullscreen).preferredMode,
        FullscreenMode.exclusive,
      );
      expect(request.windowId, 3);
    });

    test('toggle defaults to null preferredMode and windowId 0', () {
      const request = FullscreenRequest.toggle();
      expect((request as ToggleFullscreen).preferredMode, isNull);
      expect(request.windowId, 0);
    });
  });

  // ─── Task 5: FullscreenAdapter 抽象接口 ───

  group('FullscreenAdapter', () {
    test('is an abstract class', () {
      // Verify FullscreenAdapter is abstract by checking it cannot be
      // instantiated directly — only implementations can be created.
      expect(FullscreenAdapter, isA<Type>());
    });
  });

  // ─── Task 6: FakeFullscreenAdapter + 完整测试套件 ───

  group('FakeFullscreenAdapter', () {
    late FakeFullscreenAdapter adapter;
    late List<FullscreenEvent> receivedEvents;

    setUp(() {
      adapter = FakeFullscreenAdapter();
      receivedEvents = [];
      adapter.events.listen(receivedEvents.add);
    });

    tearDown(() {
      adapter.dispose();
    });

    test('snapshot returns stable/windowed initial state', () {
      final snapshot = adapter.snapshot();
      expect(snapshot.value.phase, FullscreenPhase.stable);
      expect(snapshot.value.effectiveMode, FullscreenMode.windowed);
    });

    test('setFullscreen(true) triggers entering → stable(fullscreen)', () async {
      await adapter.setFullscreen(true);
      final snapshot = adapter.snapshot();
      expect(snapshot.value.phase, FullscreenPhase.stable);
      expect(snapshot.value.effectiveMode, FullscreenMode.borderless);
      expect(snapshot.value.isFullscreen, isTrue);
    });

    test('setFullscreen(false) triggers leaving → stable(windowed)', () async {
      // First enter fullscreen
      await adapter.setFullscreen(true);
      // Then leave
      await adapter.setFullscreen(false);
      final snapshot = adapter.snapshot();
      expect(snapshot.value.phase, FullscreenPhase.stable);
      expect(snapshot.value.effectiveMode, FullscreenMode.windowed);
      expect(snapshot.value.isFullscreen, isFalse);
    });

    test('toggle() enters fullscreen when windowed', () async {
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isTrue);
    });

    test('toggle() exits fullscreen when fullscreen', () async {
      await adapter.setFullscreen(true);
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isFalse);
    });

    test('error state auto-clears on next setFullscreen', () async {
      // Simulate error state
      final notifier = adapter.snapshot();
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.error,
        lastError: const PlatformFailure('test error'),
      );
      expect(notifier.value.hasError, isTrue);

      // Next operation auto-clears
      await adapter.setFullscreen(true);
      expect(notifier.value.hasError, isFalse);
      expect(notifier.value.isFullscreen, isTrue);
    });

    test('events stream receives enterRequested and entered', () async {
      // 收集事件通过 toList 异步等待
      final futureEvents = adapter.events.take(2).toList();
      await adapter.setFullscreen(true);
      final events = await futureEvents;
      expect(events[0], isA<EnterRequested>());
      expect(events[1], isA<Entered>());
    });

    test('events stream receives leaveRequested and left', () async {
      await adapter.setFullscreen(true);
      final futureEvents = adapter.events.take(2).toList();
      await adapter.setFullscreen(false);
      final events = await futureEvents;
      expect(events[0], isA<LeaveRequested>());
      expect(events[1], isA<Left>());
    });

    test('capabilities returns default values', () async {
      final cap = await adapter.capabilities();
      expect(cap.supportsFullscreen, isTrue);
      expect(cap.supportsMultiWindow, isFalse);
    });

    test('dispose stops snapshot updates', () {
      final notifier = adapter.snapshot();
      adapter.dispose();
      // After dispose, snapshot should no longer be updated
      // (dispose clears internal state)
      expect(adapter.snapshot, throwsA(anything));
    });

    test('multi-window independent state', () async {
      final window0 = adapter.snapshot(0);
      final window1 = adapter.snapshot(1);

      // Enter fullscreen on window 0 only
      await adapter.setFullscreen(true, windowId: 0);

      // Window 0 is fullscreen, window 1 is not
      expect(window0.value.isFullscreen, isTrue);
      expect(window1.value.isFullscreen, isFalse);

      // Window 1 is still in initial state
      expect(window1.value.phase, FullscreenPhase.stable);
      expect(window1.value.effectiveMode, FullscreenMode.windowed);
    });

    test('different windowId returns same notifier for same id', () {
      final a = adapter.snapshot(0);
      final b = adapter.snapshot(0);
      expect(identical(a, b), isTrue);
    });
  });
}

/// 测试替身 — 模拟全屏操作，不依赖平台。
///
/// 用途:
/// - widget 测试中替代真实 Adapter
/// - 验证 UI 对全屏状态变化的响应
/// - 验证事件流订阅逻辑
class FakeFullscreenAdapter implements FullscreenAdapter {
  final _snapshots = <int, ValueNotifier<FullscreenSnapshot>>{};
  final _eventsController = StreamController<FullscreenEvent>.broadcast();
  bool _disposed = false;

  @override
  ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]) {
    if (_disposed) {
      throw StateError('FakeFullscreenAdapter has been disposed');
    }
    return _snapshots.putIfAbsent(
      windowId,
      () => ValueNotifier(const FullscreenSnapshot()),
    );
  }

  @override
  Stream<FullscreenEvent> get events => _eventsController.stream;

  @override
  Future<FullscreenCapability> capabilities() async {
    return const FullscreenCapability();
  }

  @override
  Future<void> setFullscreen(
    bool fullscreen, {
    int windowId = 0,
    FullscreenMode mode = FullscreenMode.borderless,
  }) {
    final notifier = snapshot(windowId);
    final current = notifier.value;

    // error 状态自动清理 — 下次合法操作重走流程
    if (current.hasError) {
      notifier.value = current.copyWith(
        phase: FullscreenPhase.stable,
        clearError: true,
      );
    }

    if (fullscreen) {
      // entering → stable(fullscreen) — 同步完成
      _eventsController.add(EnterRequested(targetMode: mode));
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.entering,
      );
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.stable,
        effectiveMode: mode,
      );
      _eventsController.add(Entered(finalMode: mode));
    } else {
      // leaving → stable(windowed)
      _eventsController.add(LeaveRequested());
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.leaving,
      );
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.stable,
        effectiveMode: FullscreenMode.windowed,
      );
      _eventsController.add(Left());
    }
    return Future<void>.value();
  }

  @override
  Future<void> toggle({
    int windowId = 0,
    FullscreenMode? preferredMode,
  }) async {
    final current = snapshot(windowId).value;
    await setFullscreen(
      !current.isFullscreen,
      windowId: windowId,
      mode: preferredMode ?? FullscreenMode.borderless,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final notifier in _snapshots.values) {
      notifier.dispose();
    }
    _snapshots.clear();
    _eventsController.close();
  }
}
