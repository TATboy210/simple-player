import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_v2/infra/event_bus/event_bus.dart';
import 'package:simple_player_v2/core/events/player_events.dart';
import 'package:simple_player_v2/core/state/playback_state.dart';

void main() {
  group('EventBus', () {
    late EventBus bus;

    setUp(() => bus = EventBus());
    tearDown(() => bus.dispose());

    test('fire/on delivers typed events', () async {
      final states = <PlaybackState>[];
      bus.on<StateChanged>().listen((e) => states.add(e.state));

      bus.fire(const StateChanged(PlaybackState.playing));
      bus.fire(const StateChanged(PlaybackState.paused));

      await Future<void>.delayed(Duration.zero);
      expect(states, [PlaybackState.playing, PlaybackState.paused]);
    });

    test('on<T> filters by type', () async {
      final positions = <int>[];
      bus.on<PositionChanged>().listen((e) => positions.add(e.positionMs));

      bus.fire(const PositionChanged(1000, 5000));
      bus.fire(const StateChanged(PlaybackState.playing));
      bus.fire(const PositionChanged(2000, 5000));

      await Future<void>.delayed(Duration.zero);
      expect(positions, [1000, 2000]);
    });

    test('stream receives all events', () async {
      final count = <int>[0];
      bus.stream.listen((_) => count[0]++);

      bus.fire(const StateChanged(PlaybackState.idle));
      bus.fire(const PositionChanged(0, 0));
      bus.fire(const VolumeChanged(50));

      await Future<void>.delayed(Duration.zero);
      expect(count[0], 3);
    });
  });
}
