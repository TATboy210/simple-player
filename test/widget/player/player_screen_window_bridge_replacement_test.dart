import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';
import '../../helpers/fake_window_service.dart';

/// Builds the injected PlayerScreen test surface without native media runtime.
Widget _buildSubject({
  required GlobalKey playerScreenKey,
  required GlobalKey videoSurfaceKey,
  required FakeEngine engine,
  required PlaybackController controller,
  required SettingsPanelController settingsPanelController,
  required FakeWindowService windowService,
  required FakeVideoControlsPort videoControls,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlayerScreen(
      key: playerScreenKey,
      engine: engine,
      mediaKitController: null,
      controller: controller,
      windowService: windowService,
      settingsPanelController: settingsPanelController,
      videoSurfaceBuilder: (_) => SizedBox.expand(key: videoSurfaceKey),
      testVideoControls: videoControls,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KernelLoggerImpl.init();
  });

  testWidgets(
    'replaces WindowBridge for title-bar commands, notifier state, and F key',
    (tester) async {
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settingsPanelController = SettingsPanelController(controller);
      final oldBridge = FakeWindowService();
      final newBridge = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final playerScreenKey = GlobalKey();
      final videoSurfaceKey = GlobalKey();

      addTearDown(() async {
        // Detach PlayerScreen before releasing the notifiers it observes.
        await tester.pumpWidget(const SizedBox.shrink());
        settingsPanelController.dispose();
        controller.dispose();
        oldBridge.dispose();
        newBridge.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settingsPanelController,
          windowService: oldBridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();
      final initialSurfaceElement = videoSurfaceKey.currentContext;
      expect(initialSurfaceElement, isNotNull);

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settingsPanelController,
          windowService: newBridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();

      // Replacement only swaps bridge-dependent caches; the injected surface stays mounted.
      expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));

      // Locate each command by its stable icon instead of relying on title-bar
      // InkWell count or child order, which are presentation details.
      Future<void> invokeTitleBarCommand(IconData icon) async {
        final command = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(InkWell),
        );
        expect(command, findsOneWidget);
        tester.widget<InkWell>(command).onTap?.call();
        await tester.pump();
      }

      await invokeTitleBarCommand(Icons.push_pin_outlined);
      await invokeTitleBarCommand(Icons.minimize);
      await invokeTitleBarCommand(Icons.close);
      await invokeTitleBarCommand(Icons.crop_square);

      expect(oldBridge.alwaysOnTopCallCount, 0);
      expect(oldBridge.minimizeCallCount, 0);
      expect(oldBridge.modeCallCount, 0);
      expect(oldBridge.closeCallCount, 0);
      expect(oldBridge.startDraggingCallCount, 0);
      expect(newBridge.alwaysOnTopCallCount, 1);
      expect(newBridge.minimizeCallCount, 1);
      expect(newBridge.lastModeValue, WindowMode.maximized);
      expect(newBridge.closeCallCount, 1);
      expect(newBridge.startDraggingCallCount, 0);

      // Old notifier updates must no longer influence the cached title bar.
      newBridge.mode.value = WindowMode.windowed;
      await tester.pump();
      oldBridge.mode.value = WindowMode.maximized;
      oldBridge.isAlwaysOnTop.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.crop_square), findsOneWidget);

      // The replacement bridge remains observable by its dynamic title control.
      newBridge.isAlwaysOnTop.value = false;
      newBridge.mode.value = WindowMode.maximized;
      await tester.pump();
      expect(find.byIcon(Icons.filter_none), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(oldBridge.modeCallCount, 0);
      expect(newBridge.lastModeValue, WindowMode.fullscreen);
    },
  );
}
