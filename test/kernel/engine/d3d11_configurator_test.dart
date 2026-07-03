import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/d3d11_configurator.dart';
import 'package:simple_player_flutter/kernel/bridge/display_config.dart';
import 'package:simple_player_flutter/kernel/engine/player_proxy.dart';

/// Fake player that implements PlayerProxy for testing.
/// Records all calls for verification.
class FakePlayer implements PlayerProxy {
  final Map<String, String> _properties = {};
  final List<String> _setPropertyCalls = [];
  double _volume = 1.0;
  bool _mute = false;

  double get volume => _volume;
  bool get mute => _mute;

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
  Map<String, String> get properties => Map.unmodifiable(_properties);
  List<String> get setPropertyCalls => List.unmodifiable(_setPropertyCalls);
}

void main() {
  group('D3D11Configurator', () {
    late FakePlayer player;
    late D3D11Configurator configurator;

    setUp(() {
      player = FakePlayer();
      configurator = D3D11Configurator(player);
      DisplayConfig.reset();
    });

    group('defaultVideoDecoders constant', () {
      test('contains shader_resource=1 for GPU colorspace conversion', () {
        expect(
          D3D11Configurator.defaultVideoDecoders,
          'D3D11:shader_resource=1,NVDEC,FFmpeg',
        );
      });

      test('includes D3D11, NVDEC, and FFmpeg decoders', () {
        expect(D3D11Configurator.defaultVideoDecoders, contains('D3D11'));
        expect(D3D11Configurator.defaultVideoDecoders, contains('NVDEC'));
        expect(D3D11Configurator.defaultVideoDecoders, contains('FFmpeg'));
      });
    });

    group('applyDefaults', () {
      test('calls setProperty 5 times', () {
        configurator.applyDefaults();
        expect(player.setPropertyCalls.length, 5);
      });

      test('sets d3d11.sync.cpu via DisplayConfig.d3d11SyncMode()', () {
        // Default is 60Hz, which returns '1' (sync mode)
        configurator.applyDefaults();
        expect(player.properties['d3d11.sync.cpu'], '1');
      });

      test('sets video.decoders to defaultVideoDecoders', () {
        configurator.applyDefaults();
        expect(
          player.properties['video.decoders'],
          D3D11Configurator.defaultVideoDecoders,
        );
      });

      test('sets avcodec.threads to 2', () {
        configurator.applyDefaults();
        expect(player.properties['avcodec.threads'], '2');
      });

      test('sets videoout.buffer_frames to 3', () {
        configurator.applyDefaults();
        expect(player.properties['videoout.buffer_frames'], '3');
      });

      test('sets reader.starts_with_key to 1', () {
        configurator.applyDefaults();
        expect(player.properties['reader.starts_with_key'], '1');
      });

      test('sets all 5 properties in correct order', () {
        configurator.applyDefaults();
        expect(player.setPropertyCalls, [
          'd3d11.sync.cpu',
          'video.decoders',
          'avcodec.threads',
          'videoout.buffer_frames',
          'reader.starts_with_key',
        ]);
      });
    });

    group('setSyncEnabled', () {
      test('sets d3d11.sync.cpu to 1 when enabled', () {
        configurator.setSyncEnabled(true);
        expect(player.properties['d3d11.sync.cpu'], '1');
      });

      test('sets d3d11.sync.cpu to 0 when disabled', () {
        configurator.setSyncEnabled(false);
        expect(player.properties['d3d11.sync.cpu'], '0');
      });
    });

    group('setHardwareDecoding', () {
      test('sets video.decoders to defaultVideoDecoders when enabled', () {
        configurator.setHardwareDecoding(true);
        expect(
          player.properties['video.decoders'],
          D3D11Configurator.defaultVideoDecoders,
        );
      });

      test('sets video.decoders to FFmpeg when disabled', () {
        configurator.setHardwareDecoding(false);
        expect(player.properties['video.decoders'], 'FFmpeg');
      });
    });

    group('DisplayConfig integration', () {
      test('uses async mode for 120Hz+ displays', () {
        // Simulate 120Hz display
        DisplayConfig.reset();
        // Note: DisplayConfig.syncModeForHz is @visibleForTesting
        // We test the policy directly
        expect(DisplayConfig.syncModeForHz(120), '0');
        expect(DisplayConfig.syncModeForHz(144), '0');
      });

      test('uses sync mode for <120Hz displays', () {
        expect(DisplayConfig.syncModeForHz(60), '1');
        expect(DisplayConfig.syncModeForHz(90), '1');
      });
    });
  });
}
