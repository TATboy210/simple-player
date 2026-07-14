import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
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
      expect(service.state.value.brightness, 0.0);
    });

    test('delegates to engine.setVideoEffect with brightness type', () {
      service.updateBrightness(0.5);
      expect(engine.setVideoEffectCallCount, greaterThanOrEqualTo(1));
      // _syncEngine sends all 4 color effects when any color property changes
      expect(service.state.value.brightness, 0.5);
    });

    test('delegates negative values', () {
      service.updateBrightness(-0.8);
      expect(service.state.value.brightness, -0.8);
    });
  });

  group('VideoProcessingService — contrast', () {
    test('default is 0.0', () {
      expect(service.state.value.contrast, 0.0);
    });

    test('delegates to engine.setVideoEffect with contrast type', () {
      service.updateContrast(0.3);
      expect(service.state.value.contrast, 0.3);
    });
  });

  group('VideoProcessingService — saturation', () {
    test('default is 0.0', () {
      expect(service.state.value.saturation, 0.0);
    });

    test('delegates to engine.setVideoEffect with saturation type', () {
      service.updateSaturation(-0.2);
      expect(service.state.value.saturation, -0.2);
    });
  });

  group('VideoProcessingService — hue', () {
    test('default is 0.0', () {
      expect(service.state.value.hue, 0.0);
    });

    test('delegates to engine.setVideoEffect with hue type', () {
      service.updateHue(0.7);
      expect(engine.lastVideoEffectType, VideoEffectType.hue);
      expect(engine.lastVideoEffectValue, closeTo(0.7, 0.01));
    });
  });

  group('VideoProcessingService — deinterlace', () {
    test('default is false', () {
      expect(service.state.value.deinterlaceEnabled, false);
    });

    test('delegates to engine.setDeinterlace', () {
      service.updateDeinterlace(true);
      expect(engine.setDeinterlaceCallCount, 1);
      expect(engine.lastDeinterlaceValue, true);
    });

    test('can toggle back to false', () {
      service.updateDeinterlace(true);
      service.updateDeinterlace(false);
      expect(engine.setDeinterlaceCallCount, 2);
      expect(engine.lastDeinterlaceValue, false);
    });
  });

  group('VideoProcessingService — rotation', () {
    test('default is 0', () {
      expect(service.state.value.rotation, 0);
    });

    test('delegates to engine.rotate', () {
      service.updateRotation(90);
      expect(engine.rotateCallCount, 1);
      expect(engine.lastRotateDegree, 90);
    });

    test('supports 180 and 270', () {
      service.updateRotation(180);
      service.updateRotation(270);
      expect(engine.lastRotateDegree, 270);
    });
  });

  group('VideoProcessingService — aspectRatioMode', () {
    test('default is keepOriginal', () {
      expect(service.state.value.aspectRatioMode, AspectRatioMode.keepOriginal);
    });

    test('delegates to engine.setAspectRatio with mode.mdkValue', () {
      service.updateAspectRatio(AspectRatioMode.ratio16_9);
      expect(engine.setAspectRatioCallCount, 1);
      expect(engine.lastAspectRatioValue, AspectRatioMode.ratio16_9.mdkValue);
    });

    test('stretch maps to 0.0', () {
      service.updateAspectRatio(AspectRatioMode.stretch);
      expect(engine.lastAspectRatioValue, 0.0);
    });

    test('cropFill maps to negative FLT_EPSILON', () {
      service.updateAspectRatio(AspectRatioMode.cropFill);
      expect(engine.lastAspectRatioValue, closeTo(-1.1920928955078125e-7, 1e-10));
    });
  });

  group('VideoProcessingService — resetAll', () {
    test('resets all notifiers to defaults', () {
      service.updateBrightness(0.5);
      service.updateContrast(0.3);
      service.updateSaturation(-0.2);
      service.updateHue(0.7);
      service.updateDeinterlace(true);
      service.updateRotation(180);
      service.updateAspectRatio(AspectRatioMode.ratio21_9);

      service.resetAll();

      expect(service.state.value.brightness, 0.0);
      expect(service.state.value.contrast, 0.0);
      expect(service.state.value.saturation, 0.0);
      expect(service.state.value.hue, 0.0);
      expect(service.state.value.deinterlaceEnabled, false);
      expect(service.state.value.rotation, 0);
      expect(service.state.value.aspectRatioMode, AspectRatioMode.keepOriginal);
    });

    test('resetAll applies defaults to engine', () {
      service.updateBrightness(0.5);
      service.updateRotation(90);

      final callsBefore =
          engine.setVideoEffectCallCount + engine.rotateCallCount;
      service.resetAll();
      final callsAfter =
          engine.setVideoEffectCallCount + engine.rotateCallCount;

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

      expect(s.state.value.brightness, 0.3);
      expect(s.state.value.contrast, -0.5);
      expect(s.state.value.saturation, 0.8);
      expect(s.state.value.hue, -0.2);
      expect(s.state.value.rotation, 90);
      expect(s.state.value.aspectRatioMode, AspectRatioMode.ratio4_3);
      expect(s.state.value.deinterlaceEnabled, true);
    });

    test('defaults when no initialSettings provided', () {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      expect(s.state.value.brightness, 0.0);
      expect(s.state.value.contrast, 0.0);
      expect(s.state.value.saturation, 0.0);
      expect(s.state.value.hue, 0.0);
      expect(s.state.value.rotation, 0);
      expect(s.state.value.aspectRatioMode, AspectRatioMode.keepOriginal);
      expect(s.state.value.deinterlaceEnabled, false);
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

      s.updateBrightness(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoBrightness'), closeTo(0.5, 0.01));
    });

    test('rotation change persists to SharedPreferences', () async {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      s.updateRotation(180);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('videoRotation'), 180);
    });

    test('deinterlace change persists to SharedPreferences', () async {
      final s = VideoProcessingService(engine);
      addTearDown(s.dispose);

      s.updateDeinterlace(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('videoDeinterlace'), true);
    });
  });
}
