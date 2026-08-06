import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';
import '../../helpers/fake_window_service.dart';

void main() {
  testWidgets(
    'shows the empty state only after stop unloads media and then enables open',
    (tester) async {
      final engine = FakeEngine()..configureMedia();
      final playlist = Playlist()..add('C:/video.mp4');
      final playlistGeneration = ValueNotifier(0);
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      final settingsPanelController = SettingsPanelController(controller);
      final windowService = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final stopGate = Completer<void>();
      var openFileCount = 0;

      addTearDown(() {
        settingsPanelController.dispose();
        controller.dispose();
        playlistGeneration.dispose();
        windowService.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      await engine.open('C:/video.mp4');
      engine.play();
      controller.currentFileName.value = 'video.mp4';
      engine.stopGate = stopGate;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlayerScreen(
            engine: engine,
            mediaKitController: null,
            controller: controller,
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            windowService: windowService,
            settingsPanelController: settingsPanelController,
            onOpenFile: () => openFileCount++,
            emptyState: EmptyState(onOpenFile: () => openFileCount++),
            videoSurfaceBuilder: (_) => const SizedBox.expand(),
            testVideoControls: videoControls,
          ),
        ),
      );

      final stopping = controller.stopCurrentMedia();
      await tester.pump();

      // Stop 尚未完成时仍加载旧媒体，不能提前暴露空置层的打开入口。
      expect(engine.hasMedia, isTrue);
      expect(find.byType(EmptyState), findsNothing);

      stopGate.complete();
      await stopping;
      await tester.pump();

      expect(engine.hasMedia, isFalse);
      expect(find.byType(EmptyState), findsOneWidget);

      final openButton = find.descendant(
        of: find.byType(EmptyState),
        matching: find.byIcon(Icons.folder_open),
      );
      await tester.tap(openButton, warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      expect(openFileCount, 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(openButton);
      expect(openFileCount, 1);

      // 键盘入口复用同一 gate；稳定窗口结束后才允许再次打开。
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      expect(openFileCount, 2);

      // 先脱树，再释放 controller/notifier，避免延迟动画的 dispose 访问旧资源。
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
