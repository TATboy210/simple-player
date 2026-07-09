import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_command_queue.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_request.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_snapshot.dart';

void main() {
  group('FullscreenCommandQueue', () {
    late FullscreenCommandQueue queue;

    setUp(() {
      queue = FullscreenCommandQueue();
    });

    tearDown(() {
      queue.dispose();
    });

    group('T1: basic enqueue', () {
      test('single enqueue calls executor once and returns true', () async {
        var callCount = 0;
        final result = await queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(result, isTrue);
        expect(callCount, equals(1));
      });

      test('single enqueue returns false when executor returns false', () async {
        final result = await queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async => false,
        );

        expect(result, isFalse);
      });
    });

    group('T2: serialization', () {
      test('second enqueue waits while first is in-flight', () async {
        final completer = Completer<bool>();
        var callCount = 0;

        // First enqueue — executor blocks on completer
        final firstFuture = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            callCount++;
            return completer.future;
          },
        );

        // Executor called immediately
        expect(callCount, equals(1));

        // Second enqueue — different target, should wait
        final secondFuture = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            callCount++;
            return true;
          },
        );

        // Executor NOT called again yet
        expect(callCount, equals(1));

        // Complete first command
        completer.complete(true);
        expect(await firstFuture, isTrue);

        // Second command now executes
        expect(await secondFuture, isTrue);
        expect(callCount, equals(2));
      });
    });

    group('T3: same-target merging', () {
      test('two enter(same mode) commands merge into one execution', () async {
        var callCount = 0;

        final firstFuture = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            callCount++;
            return true;
          },
        );

        // Second enter with same mode — should merge
        final secondFuture = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(await firstFuture, isTrue);
        expect(await secondFuture, isTrue);
        // Only one executor call — second was merged
        expect(callCount, equals(1));
      });

      test('three leave commands merge into one execution', () async {
        var callCount = 0;

        final f1 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            callCount++;
            return true;
          },
        );
        final f2 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            callCount++;
            return true;
          },
        );
        final f3 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(await f1, isTrue);
        expect(await f2, isTrue);
        expect(await f3, isTrue);
        expect(callCount, equals(1));
      });

      test('different modes do not merge', () async {
        var callCount = 0;
        final completer = Completer<bool>();

        final f1 = queue.enqueue(
          const FullscreenRequest.enter(
            mode: FullscreenMode.borderless,
          ),
          (req) async {
            callCount++;
            return completer.future;
          },
        );

        // Different mode — should NOT merge, queued as pending
        final f2 = queue.enqueue(
          const FullscreenRequest.enter(
            mode: FullscreenMode.exclusive,
          ),
          (req) async {
            callCount++;
            return true;
          },
        );

        // First is in-flight, second is pending (not merged)
        expect(callCount, equals(1));

        completer.complete(true);
        expect(await f1, isTrue);
        expect(await f2, isTrue);
        expect(callCount, equals(2));
      });
    });

    group('T4: toggle merging', () {
      test('toggle (not fullscreen) resolves to enter and merges with enter',
          () async {
        var callCount = 0;

        // toggle when not fullscreen → resolves to EnterFullscreen
        final f1 = queue.enqueue(
          const FullscreenRequest.toggle(),
          (req) async {
            callCount++;
            return true;
          },
          currentFullscreen: false,
        );

        // Enter with same target — should merge
        final f2 = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(await f1, isTrue);
        expect(await f2, isTrue);
        expect(callCount, equals(1));
      });

      test('T11: toggle (fullscreen) resolves to leave and merges with leave',
          () async {
        var callCount = 0;

        // toggle when fullscreen → resolves to LeaveFullscreen
        final f1 = queue.enqueue(
          const FullscreenRequest.toggle(),
          (req) async {
            callCount++;
            return true;
          },
          currentFullscreen: true,
        );

        // Leave with same target — should merge
        final f2 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(await f1, isTrue);
        expect(await f2, isTrue);
        expect(callCount, equals(1));
      });
    });

    group('T5: timeout', () {
      test('executor exceeding timeout completes with false', () async {
        final result = await queue.enqueue(
          const FullscreenRequest.enter(),
          // Never completes — simulates hung native call
          (req) => Completer<bool>().future,
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, isFalse);
      });

      test('timeout completes in-flight and drains pending', () async {
        var executorCallCount = 0;
        final completer = Completer<bool>();

        // First command — will be manually completed after timeout check
        final f1 = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            executorCallCount++;
            return completer.future;
          },
          timeout: const Duration(milliseconds: 100),
        );

        // Second command — different target, becomes pending
        final f2 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            executorCallCount++;
            return true;
          },
        );

        // Complete first command before timeout
        completer.complete(true);
        expect(await f1, isTrue);

        // Second command should execute via drain
        expect(await f2, isTrue);
        expect(executorCallCount, equals(2));
      });
    });

    group('T6: per-windowId isolation', () {
      test('different windowIds execute independently', () async {
        var callCount = 0;
        final completer0 = Completer<bool>();

        // windowId=0 blocks
        final f0 = queue.enqueue(
          const FullscreenRequest.enter(windowId: 0),
          (req) async {
            callCount++;
            return completer0.future;
          },
        );

        // windowId=1 executes immediately (independent queue)
        final f1 = queue.enqueue(
          const FullscreenRequest.enter(windowId: 1),
          (req) async {
            callCount++;
            return true;
          },
        );

        expect(await f1, isTrue);
        expect(callCount, equals(2));

        completer0.complete(true);
        expect(await f0, isTrue);
      });
    });

    group('T7/T8/T9: dispose lifecycle', () {
      test('T7: enqueue after dispose throws StateError', () {
        queue.dispose();

        // StateError is thrown synchronously before returning Future
        expect(
          () => queue.enqueue(
            const FullscreenRequest.enter(),
            (req) async => true,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('T8: dispose completes pending with false', () async {
        final completer = Completer<bool>();

        // First blocks
        final f1 = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async => completer.future,
        );

        // Second queued as pending
        final f2 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async => true,
        );

        // Dispose — pending should complete with false
        queue.dispose();

        expect(await f2, isFalse);

        // Complete in-flight manually
        completer.complete(true);
        expect(await f1, isTrue);
      });

      test('T9: dispose does not drain pending after in-flight completes',
          () async {
        final completer = Completer<bool>();
        var executorCallCount = 0;

        // First blocks
        final f1 = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async {
            executorCallCount++;
            return completer.future;
          },
        );

        // Second queued — different target, as pending
        final f2 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async {
            executorCallCount++;
            return true;
          },
        );

        // Dispose before first completes — pending gets false immediately
        queue.dispose();

        expect(await f2, isFalse);
        expect(executorCallCount, equals(1));

        // Now complete in-flight — should NOT trigger pending's executor
        completer.complete(true);
        expect(await f1, isTrue);
        expect(executorCallCount, equals(1));
      });
    });

    group('T10: queue capacity', () {
      test('maxQueueSize constant is 50', () {
        expect(FullscreenCommandQueue.maxQueueSize, equals(50));
      });
    });

    group('edge cases', () {
      test('executor exception propagates as false', () async {
        final result = await queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async => throw Exception('native crash'),
        );

        expect(result, isFalse);
      });

      test('toggle with preferredMode passes mode to resolved enter', () async {
        FullscreenRequest? capturedRequest;

        await queue.enqueue(
          const FullscreenRequest.toggle(
            preferredMode: FullscreenMode.exclusive,
          ),
          (req) async {
            capturedRequest = req;
            return true;
          },
          currentFullscreen: false,
        );

        // toggle resolved to enter with exclusive mode
        expect(capturedRequest, isA<EnterFullscreen>());
        expect(
          (capturedRequest as EnterFullscreen).mode,
          equals(FullscreenMode.exclusive),
        );
      });

      test('pending replacement completes old pending with false', () async {
        final completer1 = Completer<bool>();

        // First blocks
        final f1 = queue.enqueue(
          const FullscreenRequest.enter(),
          (req) async => completer1.future,
        );

        // Second — different target, becomes pending
        final f2 = queue.enqueue(
          const FullscreenRequest.enter(
            mode: FullscreenMode.exclusive,
          ),
          (req) async => true,
        );

        // Third — different from second, REPLACES second as pending
        final f3 = queue.enqueue(
          const FullscreenRequest.leave(),
          (req) async => true,
        );

        // f2 (the replaced pending) should complete with false
        expect(await f2, isFalse);

        // Complete first
        completer1.complete(true);
        expect(await f1, isTrue);

        // f3 (the replacement) should execute and succeed
        expect(await f3, isTrue);
      });
    });
  });
}
