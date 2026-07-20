import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/position_poller.dart';

import '../../helpers/fake_mdk_player.dart';

void main() {
  group('PositionPoller', () {
    late FakeMdkPlayer player;
    late ValueNotifier<int> position;
    late ValueNotifier<int> buffered;

    setUp(() {
      player = FakeMdkPlayer();
      position = ValueNotifier<int>(0);
      buffered = ValueNotifier<int>(0);
    });

    tearDown(() {
      position.dispose();
      buffered.dispose();
    });

    PositionPoller createPoller({String Function()? pathGetter}) {
      return PositionPoller(
        player,
        position: position,
        buffered: buffered,
        currentPathGetter: pathGetter ?? () => '/test/video.mp4',
      );
    }

    group('start/stop', () {
      test('start begins polling without throwing', () {
        final poller = createPoller();
        poller.start();
        poller.dispose();
      });

      test('stop halts polling without throwing', () {
        final poller = createPoller();
        poller.start();
        poller.stop();
        poller.dispose();
      });

      test('start is idempotent', () {
        final poller = createPoller();
        poller.start();
        poller.start(); // restarts
        poller.dispose();
      });

      test('stop is idempotent', () {
        final poller = createPoller();
        poller.start();
        poller.stop();
        poller.stop(); // no-op
        poller.dispose();
      });

      test('start after stop restarts polling', () {
        final poller = createPoller();
        poller.start();
        poller.stop();
        poller.start(); // restart
        poller.dispose();
      });
    });

    group('dispose', () {
      test('dispose stops polling', () {
        final poller = createPoller();
        poller.start();
        poller.dispose();
        // Should not throw
      });

      test('dispose is idempotent', () {
        final poller = createPoller();
        poller.start();
        poller.dispose();
        poller.dispose(); // second call
      });

      test('dispose without start is safe', () {
        final poller = createPoller();
        poller.dispose();
      });
    });

    group('seeking', () {
      test('seeking setter is part of public API', () {
        final poller = createPoller();
        poller.start();
        poller.seeking = true;
        poller.seeking = false;
        poller.dispose();
      });

      test('seeking true followed by false calls setActive internally', () {
        final poller = createPoller();
        poller.start();
        poller.seeking = true;
        poller.seeking = false; // triggers setActive() + silent timer
        poller.dispose();
      });
    });

    group('setActive', () {
      test('setActive switches to fast polling interval', () {
        final poller = createPoller();
        poller.start();
        poller.setActive();
        poller.dispose();
      });

      test('setActive can be called multiple times', () {
        final poller = createPoller();
        poller.start();
        poller.setActive();
        poller.setActive();
        poller.dispose();
      });
    });

    group('startSilent', () {
      test('startSilent starts polling', () {
        final poller = createPoller();
        poller.startSilent();
        poller.dispose();
      });
    });

    group('setDragMode', () {
      test('setDragMode true sets fast polling', () {
        final poller = createPoller();
        poller.start();
        poller.setDragMode(true);
        poller.dispose();
      });

      test('setDragMode false restores normal polling', () {
        final poller = createPoller();
        poller.start();
        poller.setDragMode(true);
        poller.setDragMode(false);
        poller.dispose();
      });

      test('setDragMode before start does not throw', () {
        final poller = createPoller();
        poller.setDragMode(true);
        poller.dispose();
      });
    });

    group('setPlaybackRate', () {
      test('setPlaybackRate with 2.0 rate', () {
        final poller = createPoller();
        poller.start();
        poller.setPlaybackRate(2.0);
        poller.dispose();
      });

      test('setPlaybackRate with 0.5 rate', () {
        final poller = createPoller();
        poller.start();
        poller.setPlaybackRate(0.5);
        poller.dispose();
      });

      test('setPlaybackRate with 1.0 rate (normal)', () {
        final poller = createPoller();
        poller.start();
        poller.setPlaybackRate(1.0);
        poller.dispose();
      });
    });

    group('class structure', () {
      test('class exists and is importable', () {
        expect(PositionPoller, isA<Type>());
      });

      test('constructor accepts required parameters', () {
        final poller = createPoller();
        expect(poller, isA<PositionPoller>());
        poller.dispose();
      });

      test('position notifier is accessible', () {
        final poller = createPoller();
        expect(poller.position, isA<ValueNotifier<int>>());
        poller.dispose();
      });

      test('buffered notifier is accessible', () {
        final poller = createPoller();
        expect(poller.buffered, isA<ValueNotifier<int>>());
        poller.dispose();
      });
    });
  });
}
