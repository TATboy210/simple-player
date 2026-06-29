import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/subtitle_configurator.dart';
import 'package:simple_player_flutter/kernel/engine/player_proxy.dart';

/// Fake player that implements PlayerProxy for testing.
/// Records all calls for verification.
class FakePlayer implements PlayerProxy {
  double _volume = 1.0;
  bool _mute = false;
  final Map<String, String> _properties = {};

  @override
  set volume(double value) => _volume = value;

  @override
  set mute(bool value) => _mute = value;

  @override
  void setProperty(String key, String value) {
    _properties[key] = value;
  }

  @override
  String? getProperty(String key) => _properties[key];

  // Test helpers
  Map<String, String> get properties => Map.unmodifiable(_properties);
}

void main() {
  group('SubtitleConfigurator', () {
    late FakePlayer player;
    late SubtitleConfigurator configurator;

    setUp(() {
      player = FakePlayer();
      configurator = SubtitleConfigurator(player);
    });

    group('setExternalSubtitle', () {
      test('sets subtitle.external property', () {
        configurator.setExternalSubtitle('test.srt');
        expect(player.properties['subtitle.external'], 'test.srt');
      });

      test('handles empty path', () {
        configurator.setExternalSubtitle('');
        expect(player.properties['subtitle.external'], '');
      });
    });

    group('setSubtitleDelay', () {
      test('sets subtitle.delay property as string', () {
        configurator.setSubtitleDelay(500);
        expect(player.properties['subtitle.delay'], '500');
      });

      test('handles zero delay', () {
        configurator.setSubtitleDelay(0);
        expect(player.properties['subtitle.delay'], '0');
      });

      test('handles negative delay', () {
        configurator.setSubtitleDelay(-300);
        expect(player.properties['subtitle.delay'], '-300');
      });
    });

    group('getSubtitleDelay', () {
      test('returns parsed delay from player', () {
        player.setProperty('subtitle.delay', '1000');
        expect(configurator.getSubtitleDelay(), 1000);
      });

      test('returns 0 when property is null', () {
        expect(configurator.getSubtitleDelay(), 0);
      });

      test('returns 0 when property is invalid', () {
        player.setProperty('subtitle.delay', 'invalid');
        expect(configurator.getSubtitleDelay(), 0);
      });
    });

    group('setEqualizer', () {
      test('sets af property', () {
        configurator.setEqualizer('af=lavfi=[equalizer=f=1000:t=q:w=1:g=5]');
        expect(
          player.properties['af'],
          'af=lavfi=[equalizer=f=1000:t=q:w=1:g=5]',
        );
      });

      test('handles empty filter', () {
        configurator.setEqualizer('');
        expect(player.properties['af'], '');
      });
    });
  });
}
