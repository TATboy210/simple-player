import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_v2/core/events/player_events.dart';

void main() {
  group('PlayerCommand', () {
    test('commands are const-constructible', () {
      expect(const OpenCommand('test.mp4'), isA<PlayerCommand>());
      expect(const PlayCommand(), isA<PlayerCommand>());
      expect(const PauseCommand(), isA<PlayerCommand>());
      expect(const TogglePlayPauseCommand(), isA<PlayerCommand>());
      expect(const StopCommand(), isA<PlayerCommand>());
      expect(const SeekCommand(1000), isA<PlayerCommand>());
      expect(const SetVolumeCommand(50), isA<PlayerCommand>());
      expect(const ToggleMuteCommand(), isA<PlayerCommand>());
      expect(const PrevCommand(), isA<PlayerCommand>());
      expect(const NextCommand(), isA<PlayerCommand>());
      expect(const VolumeUpCommand(), isA<PlayerCommand>());
      expect(const VolumeDownCommand(), isA<PlayerCommand>());
      expect(const ToggleFullscreenCommand(), isA<PlayerCommand>());
      expect(const SkipForwardCommand(), isA<PlayerCommand>());
      expect(const SkipBackwardCommand(), isA<PlayerCommand>());
    });

    test('OpenCommand carries path', () {
      const cmd = OpenCommand('/path/to/video.mp4');
      expect(cmd.path, '/path/to/video.mp4');
    });

    test('SeekCommand carries positionMs', () {
      const cmd = SeekCommand(42000);
      expect(cmd.positionMs, 42000);
    });

    test('SetVolumeCommand carries volume', () {
      const cmd = SetVolumeCommand(75.5);
      expect(cmd.volume, 75.5);
    });

    test('SkipForwardCommand default seconds', () {
      const cmd = SkipForwardCommand();
      expect(cmd.seconds, 10);
      const cmd30 = SkipForwardCommand(seconds: 30);
      expect(cmd30.seconds, 30);
    });

    test('sealed class exhaustive matching', () {
      String describe(PlayerCommand cmd) => switch (cmd) {
        OpenCommand(:final path) => 'open:$path',
        PlayCommand() => 'play',
        PauseCommand() => 'pause',
        TogglePlayPauseCommand() => 'toggle',
        StopCommand() => 'stop',
        SeekCommand(:final positionMs) => 'seek:$positionMs',
        SetVolumeCommand(:final volume) => 'vol:$volume',
        ToggleMuteCommand() => 'mute',
        PrevCommand() => 'prev',
        NextCommand() => 'next',
        VolumeUpCommand() => 'vol_up',
        VolumeDownCommand() => 'vol_down',
        ToggleFullscreenCommand() => 'fullscreen',
        SkipForwardCommand(:final seconds) => 'skip_fwd:$seconds',
        SkipBackwardCommand(:final seconds) => 'skip_bwd:$seconds',
      };

      expect(describe(const OpenCommand('a.mp4')), 'open:a.mp4');
      expect(describe(const TogglePlayPauseCommand()), 'toggle');
      expect(describe(const SkipForwardCommand(seconds: 30)), 'skip_fwd:30');
    });
  });
}
