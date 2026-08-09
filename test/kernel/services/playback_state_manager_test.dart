import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late PlaybackController controller;

  setUp(() {
    // 为 SettingsStore 提供平台无关的内存后端，避免测试依赖宿主插件。
    SharedPreferences.setMockInitialValues({});
    engine = FakeEngine();
    controller = PlaybackController(engine: engine);
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('PlaybackStateManager', () {
    group('init', () {
      test('init with preloaded settings sets volume and mute', () async {
        const settings = AppSettings(
          volume: 0.7,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: true,
        );

        await controller.init(settings: settings);

        expect(engine.volume.value, closeTo(0.7, 0.01));
        expect(engine.isMuted.value, isTrue);
      });

      test('init is idempotent', () async {
        const settings = AppSettings(
          volume: 0.5,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: false,
        );

        await controller.init(settings: settings);
        // 第二次初始化不应覆盖已恢复的单文件播放设置。
        await controller.init(settings: settings);

        expect(engine.volume.value, closeTo(0.5, 0.01));
      });

      test('init without settings leaves engine in idle state', () async {
        // SettingsStore 在测试环境可能无法访问平台存储；初始化必须保持安全。
        await controller.init();

        expect(engine.state.value, MediaState.idle);
      });
    });
  });
}
