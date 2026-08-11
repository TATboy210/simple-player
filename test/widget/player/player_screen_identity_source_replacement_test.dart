import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';
import '../../helpers/fake_window_service.dart';

/// Builds a headless PlayerScreen with stable keys for identity assertions.
Widget _buildSubject({
  required GlobalKey playerScreenKey,
  required GlobalKey videoSurfaceKey,
  required FakeEngine engine,
  required PlaybackController controller,
  required SettingsPanelController settingsPanelController,
  required FakeWindowService windowService,
  required FakeVideoControlsPort videoControls,
  void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary,
  void Function(List<String> paths)? onFilesDropped,
  void Function(bool hovering)? onDragHoverChanged,
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
      onSettingsSecondary: onSettingsSecondary,
      onFilesDropped: onFilesDropped,
      onDragHoverChanged: onDragHoverChanged,
    ),
  );
}

/// Captures the three PlayerScreen subtrees whose elements must survive shell updates.
({BuildContext title, BuildContext surface, BuildContext controls})
_coreContexts(WidgetTester tester, GlobalKey videoSurfaceKey) {
  final title = tester.element(find.byType(CustomTitleBar));
  final controls = tester.element(find.byType(PlayerVideoControls));
  final surface = videoSurfaceKey.currentContext;
  expect(surface, isNotNull);
  return (title: title, surface: surface!, controls: controls);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KernelLoggerImpl.init();
  });

  testWidgets(
    'keeps title surface and controls elements through shell mode and resize updates',
    (tester) async {
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settings = SettingsPanelController(controller);
      final bridge = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final playerScreenKey = GlobalKey();
      final videoSurfaceKey = GlobalKey();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
        controller.dispose();
        bridge.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settings,
          windowService: bridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();
      final initial = _coreContexts(tester, videoSurfaceKey);

      // Re-pumping the same keyed shell models a parent rebuild unrelated to playback.
      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settings,
          windowService: bridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();
      expect(_coreContexts(tester, videoSurfaceKey).title, same(initial.title));
      expect(
        _coreContexts(tester, videoSurfaceKey).surface,
        same(initial.surface),
      );
      expect(
        _coreContexts(tester, videoSurfaceKey).controls,
        same(initial.controls),
      );

      bridge.mode.value = WindowMode.maximized;
      await tester.pump();
      expect(_coreContexts(tester, videoSurfaceKey).title, same(initial.title));
      expect(
        _coreContexts(tester, videoSurfaceKey).surface,
        same(initial.surface),
      );
      expect(
        _coreContexts(tester, videoSurfaceKey).controls,
        same(initial.controls),
      );

      for (var session = 0; session < 3; session++) {
        bridge.isResizing.value = true;
        await tester.pump();
        bridge.isResizing.value = false;
        await tester.pump();
        final current = _coreContexts(tester, videoSurfaceKey);
        expect(current.title, same(initial.title));
        expect(current.surface, same(initial.surface));
        expect(current.controls, same(initial.controls));
      }
    },
  );

  testWidgets(
    'bridge replacement isolates old notifiers and retains video elements',
    (tester) async {
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settings = SettingsPanelController(controller);
      final oldBridge = FakeWindowService();
      final newBridge = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final playerScreenKey = GlobalKey();
      final videoSurfaceKey = GlobalKey();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
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
          settingsPanelController: settings,
          windowService: oldBridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();
      final initial = _coreContexts(tester, videoSurfaceKey);

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settings,
          windowService: newBridge,
          videoControls: videoControls,
        ),
      );
      await tester.pump();
      final replacement = _coreContexts(tester, videoSurfaceKey);
      // The title element updates its bridge-dependent widget in place; only the
      // injected video tree is required to retain its element identity.
      expect(replacement.title, same(initial.title));
      expect(replacement.surface, same(initial.surface));
      expect(replacement.controls, same(initial.controls));

      oldBridge.mode.value = WindowMode.fullscreen;
      oldBridge.isResizing.value = true;
      await tester.pump();
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
            .opacity,
        1.0,
      );

      newBridge.mode.value = WindowMode.fullscreen;
      await tester.pump();
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
            .opacity,
        0.0,
      );
    },
  );

  testWidgets(
    'callback replacement dispatches only current host callbacks without replacing controls',
    (tester) async {
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settings = SettingsPanelController(controller);
      final bridge = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final playerScreenKey = GlobalKey();
      final videoSurfaceKey = GlobalKey();
      var oldSettingsCalls = 0;
      var newSettingsCalls = 0;
      final oldDroppedPaths = <List<String>>[];
      final newDroppedPaths = <List<String>>[];
      final oldHoverStates = <bool>[];
      final newHoverStates = <bool>[];

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
        controller.dispose();
        bridge.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settings,
          windowService: bridge,
          videoControls: videoControls,
          onSettingsSecondary: (_, _) => oldSettingsCalls++,
          onFilesDropped: oldDroppedPaths.add,
          onDragHoverChanged: oldHoverStates.add,
        ),
      );
      await tester.pump();
      final initial = _coreContexts(tester, videoSurfaceKey);

      await tester.pumpWidget(
        _buildSubject(
          playerScreenKey: playerScreenKey,
          videoSurfaceKey: videoSurfaceKey,
          engine: engine,
          controller: controller,
          settingsPanelController: settings,
          windowService: bridge,
          videoControls: videoControls,
          onSettingsSecondary: (_, _) => newSettingsCalls++,
          onFilesDropped: newDroppedPaths.add,
          onDragHoverChanged: newHoverStates.add,
        ),
      );
      await tester.pump();
      expect(
        _coreContexts(tester, videoSurfaceKey).controls,
        same(initial.controls),
      );

      final actions = tester
          .widget<PlayerVideoControls>(find.byType(PlayerVideoControls))
          .actions;
      actions.onSettingsSecondary?.call(
        tester.element(find.byType(PlayerVideoControls)),
        TapUpDetails(
          globalPosition: Offset.zero,
          kind: PointerDeviceKind.mouse,
        ),
      );
      actions.onFilesDropped?.call(['replacement.mp4']);
      actions.onDragHoverChanged?.call(true);

      expect(oldSettingsCalls, 0);
      expect(newSettingsCalls, 1);
      expect(oldDroppedPaths, isEmpty);
      expect(newDroppedPaths, [
        <String>['replacement.mp4'],
      ]);
      expect(oldHoverStates, isEmpty);
      expect(newHoverStates, [true]);
    },
  );

  testWidgets('controller and engine replacement use only new sources', (
    tester,
  ) async {
    final oldEngine = FakeEngine();
    final newEngine = FakeEngine();
    final oldController = PlaybackController(engine: oldEngine);
    final newController = PlaybackController(engine: newEngine);
    final oldSettings = SettingsPanelController(oldController);
    final newSettings = SettingsPanelController(newController);
    final bridge = FakeWindowService();
    final videoControls = FakeVideoControlsPort();
    final playerScreenKey = GlobalKey();
    final videoSurfaceKey = GlobalKey();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      oldSettings.dispose();
      newSettings.dispose();
      oldController.dispose();
      newController.dispose();
      bridge.dispose();
      videoControls.dispose();
      oldEngine.dispose();
      newEngine.dispose();
    });

    await tester.pumpWidget(
      _buildSubject(
        playerScreenKey: playerScreenKey,
        videoSurfaceKey: videoSurfaceKey,
        engine: oldEngine,
        controller: oldController,
        settingsPanelController: oldSettings,
        windowService: bridge,
        videoControls: videoControls,
      ),
    );
    await tester.pump();
    final initialSurface = videoSurfaceKey.currentContext;

    await tester.pumpWidget(
      _buildSubject(
        playerScreenKey: playerScreenKey,
        videoSurfaceKey: videoSurfaceKey,
        engine: newEngine,
        controller: newController,
        settingsPanelController: newSettings,
        windowService: bridge,
        videoControls: videoControls,
      ),
    );
    await tester.pump();

    expect(videoSurfaceKey.currentContext, same(initialSurface));
    oldController.currentFileName.value = 'old.mp4';
    await tester.pump();
    expect(find.text('old.mp4'), findsNothing);

    newController.currentFileName.value = 'new.mp4';
    await tester.pump();
    expect(find.text('new.mp4'), findsOneWidget);

    // The stable actions object must select the current controller at invocation time.
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    expect(oldEngine.togglePlayPauseCallCount, 0);
    expect(newEngine.togglePlayPauseCallCount, 1);
  });
}
