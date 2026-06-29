import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_player_flutter/kernel/engine/volume_controller.dart';
import 'package:simple_player_flutter/kernel/engine/player_proxy.dart';

/// Fake player that implements PlayerProxy for testing.
/// Records all calls for verification.
class FakePlayer implements PlayerProxy {
  double _volume = 1.0;
  bool _mute = false;
  final Map<String, String> _properties = {};
  final List<String> _setPropertyCalls = [];

  @override
  set volume(double value) => _volume = value;

  @override
  set mute(bool value) => _mute = value;

  @override
  void setProperty(String key, String value) {
    _properties[key] = value;
    _setPropertyCalls.add(key);
  }

  @override
  String? getProperty(String key) => _properties[key];

  // Test helpers
  double get testVolume => _volume;
  bool get testMute => _mute;
  List<String> get setPropertyCalls => List.unmodifiable(_setPropertyCalls);
}

void main() {
  group('VolumeController', () {
    late FakePlayer player;
    late ValueNotifier<double> volume;
    late ValueNotifier<bool> isMuted;
    late VolumeController controller;

    setUp(() {
      player = FakePlayer();
      volume = ValueNotifier<double>(1.0);
      isMuted = ValueNotifier<bool>(false);
      controller = VolumeController(player, volume: volume, isMuted: isMuted);
    });

    tearDown(() {
      volume.dispose();
      isMuted.dispose();
    });

    group('setVolume', () {
      test('sets player volume and volume.value', () {
        controller.setVolume(0.5);
        expect(player.testVolume, 0.5);
        expect(volume.value, 0.5);
        expect(isMuted.value, false);
      });

      test('auto-mutes when volume reaches zero', () {
        controller.setVolume(0.0);
        expect(player.testVolume, 0.0);
        expect(player.testMute, true);
        expect(isMuted.value, true);
      });

      test('auto-unmutes when raised from zero', () {
        // Start muted
        isMuted.value = true;
        player.mute = true;

        controller.setVolume(0.8);
        expect(player.testVolume, 0.8);
        expect(player.testMute, false);
        expect(isMuted.value, false);
      });

      test('clamps to 1.0 when value exceeds range', () {
        controller.setVolume(1.5);
        expect(player.testVolume, 1.0);
        expect(volume.value, 1.0);
      });

      test('clamps to 0.0 when value is negative', () {
        controller.setVolume(-0.1);
        expect(player.testVolume, 0.0);
        expect(volume.value, 0.0);
        expect(isMuted.value, true);
      });

      test('does not auto-mute when already muted and volume is 0', () {
        isMuted.value = true;
        player.mute = true;

        controller.setVolume(0.0);
        expect(player.testVolume, 0.0);
        expect(player.testMute, true);
        expect(isMuted.value, true);
      });
    });

    group('setMute', () {
      test('sets mute to true', () {
        controller.setMute(true);
        expect(player.testMute, true);
        expect(isMuted.value, true);
      });

      test('sets mute to false', () {
        isMuted.value = true;
        player.mute = true;

        controller.setMute(false);
        expect(player.testMute, false);
        expect(isMuted.value, false);
      });

      test('does not change volume when muting', () {
        controller.setVolume(0.7);
        controller.setMute(true);
        expect(player.testVolume, 0.7);
        expect(volume.value, 0.7);
      });
    });
  });
}
