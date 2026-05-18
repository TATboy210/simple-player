import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/models/video_effect_type.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late VideoProcessingService service;

  setUp(() {
    engine = FakeEngine();
    service = VideoProcessingService(engine);
  });

  tearDown(() {
    service.dispose();
    engine.dispose();
  });

  group('VideoProcessingService — brightness', () {
    test('default is 0.0', () {
      expect(service.brightness.value, 0.0);
    });

    test('delegates to engine.setVideoEffect with brightness type', () {
      service.brightness.value = 0.5;
      expect(engine.setVideoEffectCallCount, 1);
      expect(engine.lastVideoEffectType, VideoEffectType.brightness);
      expect(engine.lastVideoEffectValue, 0.5);
    });

    test('delegates negative values', () {
      service.brightness.value = -0.8;
      expect(engine.lastVideoEffectValue, -0.8);
    });
  });

  group('VideoProcessingService — contrast', () {
    test('default is 0.0', () {
      expect(service.contrast.value, 0.0);
    });

    test('delegates to engine.setVideoEffect with contrast type', () {
      service.contrast.value = 0.3;
      expect(engine.setVideoEffectCallCount, 1);
      expect(engine.lastVideoEffectType, VideoEffectType.contrast);
      expect(engine.lastVideoEffectValue, 0.3);
    });
  });

  group('VideoProcessingService — saturation', () {
    test('default is 0.0', () {
      expect(service.saturation.value, 0.0);
    });

    test('delegates to engine.setVideoEffect with saturation type', () {
      service.saturation.value = -0.2;
      expect(engine.setVideoEffectCallCount, 1);
      expect(engine.lastVideoEffectType, VideoEffectType.saturation);
      expect(engine.lastVideoEffectValue, -0.2);
    });
  });

  group('VideoProcessingService — hue', () {
    test('default is 0.0', () {
      expect(service.hue.value, 0.0);
    });

    test('delegates to engine.setVideoEffect with hue type', () {
      service.hue.value = 0.7;
      expect(engine.setVideoEffectCallCount, 1);
      expect(engine.lastVideoEffectType, VideoEffectType.hue);
      expect(engine.lastVideoEffectValue, 0.7);
    });
  });

  group('VideoProcessingService — deinterlace', () {
    test('default is false', () {
      expect(service.deinterlaceEnabled.value, false);
    });

    test('delegates to engine.setDeinterlace', () {
      service.deinterlaceEnabled.value = true;
      expect(engine.setDeinterlaceCallCount, 1);
      expect(engine.lastDeinterlaceValue, true);
    });

    test('can toggle back to false', () {
      service.deinterlaceEnabled.value = true;
      service.deinterlaceEnabled.value = false;
      expect(engine.setDeinterlaceCallCount, 2);
      expect(engine.lastDeinterlaceValue, false);
    });
  });

  group('VideoProcessingService — rotation', () {
    test('default is 0', () {
      expect(service.rotation.value, 0);
    });

    test('delegates to engine.rotate', () {
      service.rotation.value = 90;
      expect(engine.rotateCallCount, 1);
      expect(engine.lastRotateDegree, 90);
    });

    test('supports 180 and 270', () {
      service.rotation.value = 180;
      service.rotation.value = 270;
      expect(engine.rotateCallCount, 2);
      expect(engine.lastRotateDegree, 270);
    });
  });

  group('VideoProcessingService — aspectRatioMode', () {
    test('default is keepOriginal', () {
      expect(service.aspectRatioMode.value, AspectRatioMode.keepOriginal);
    });

    test('delegates to engine.setAspectRatio with mode.mdkValue', () {
      service.aspectRatioMode.value = AspectRatioMode.ratio16_9;
      expect(engine.setAspectRatioCallCount, 1);
      expect(engine.lastAspectRatioValue, AspectRatioMode.ratio16_9.mdkValue);
    });

    test('stretch maps to 0.0', () {
      service.aspectRatioMode.value = AspectRatioMode.stretch;
      expect(engine.lastAspectRatioValue, 0.0);
    });

    test('cropFill maps to negative FLT_EPSILON', () {
      service.aspectRatioMode.value = AspectRatioMode.cropFill;
      expect(engine.lastAspectRatioValue, -1.1920928955078125e-7);
    });
  });

  group('VideoProcessingService — resetAll', () {
    test('resets all notifiers to defaults', () {
      // Set all to non-default values
      service.brightness.value = 0.5;
      service.contrast.value = 0.3;
      service.saturation.value = -0.2;
      service.hue.value = 0.7;
      service.deinterlaceEnabled.value = true;
      service.rotation.value = 180;
      service.aspectRatioMode.value = AspectRatioMode.ratio21_9;

      service.resetAll();

      expect(service.brightness.value, 0.0);
      expect(service.contrast.value, 0.0);
      expect(service.saturation.value, 0.0);
      expect(service.hue.value, 0.0);
      expect(service.deinterlaceEnabled.value, false);
      expect(service.rotation.value, 0);
      expect(service.aspectRatioMode.value, AspectRatioMode.keepOriginal);
    });

    test('resetAll applies defaults to engine', () {
      service.brightness.value = 0.5;
      service.rotation.value = 90;

      final callsBefore =
          engine.setVideoEffectCallCount + engine.rotateCallCount;
      service.resetAll();
      final callsAfter =
          engine.setVideoEffectCallCount + engine.rotateCallCount;

      // resetAll triggers listeners which call engine methods
      expect(callsAfter, greaterThan(callsBefore));
    });
  });

  group('VideoProcessingService — dispose', () {
    test('dispose does not throw', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('VideoProcessingService — initialSettings', () {
    test('initializes from AppSettings values', () {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        videoBrightness: 0.3,
        videoContrast: -0.5,
        videoSaturation: 0.8,
        videoHue: -0.2,
        videoRotation: 90,
        videoAspectRatioIndex: 3,
        videoDeinterlace: true,
      );

      final s = VideoProcessingService(engine, initialSettings: settings);
      addTearDown(s.dispose);

      expect(s.brightness.value, 0.3);
      expect(s.contrast.value, -0.5);
      expect(s.saturation.value, 0.8);
      expect(s.hue.value, -0.2);
      expect(s.rotation.value, 90);
      expect(s.aspectRatioMode.value, AspectRatioMode.ratio4_3);
      expect(s.deinterlaceEnabled.value, true);
    });

    test('defaults when no initialSettings provided', () {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      expect(s.brightness.value, 0.0);
      expect(s.contrast.value, 0.0);
      expect(s.saturation.value, 0.0);
      expect(s.hue.value, 0.0);
      expect(s.rotation.value, 0);
      expect(s.aspectRatioMode.value, AspectRatioMode.keepOriginal);
      expect(s.deinterlaceEnabled.value, false);
    });
  });

  group('VideoProcessingService — persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SettingsStore.resetPrewarm();
    });

    test('brightness change persists to SharedPreferences', () async {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      s.brightness.value = 0.5;
      // Wait for debounce (50ms) + async save
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoBrightness'), closeTo(0.5, 0.01));
    });

    test('rotation change persists to SharedPreferences', () async {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      s.rotation.value = 180;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('videoRotation'), 180);
    });

    test('deinterlace change persists to SharedPreferences', () async {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      s.deinterlaceEnabled.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('videoDeinterlace'), true);
    });
  });
}
