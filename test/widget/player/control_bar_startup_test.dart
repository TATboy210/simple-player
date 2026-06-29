import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import '../../helpers/fake_engine.dart';

/// 验证控制栏在启动时（emptyState + idle）的可见性和交互性
void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildSubject({
    EngineState? eng,
    PlayerActions? actions,
    bool emptyStatePresent = false,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ControlsOverlay(
            engine: eng ?? engine,
            actions: actions ??
                PlayerActions(
                  onOpenFile: () {},
                  onSettings: () {},
                  onToggleFullscreen: () {},
                ),
            emptyStatePresent: emptyStatePresent,
          ),
        ),
      ),
    );
  }

  group('ControlBar startup visibility', () {
    testWidgets('visible at startup (idle, no emptyState)', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);

      // 不应有 Offstage(offstage: true) 隐藏控制栏
      final offstageList = tester.widgetList(find.byType(Offstage));
      for (final o in offstageList) {
        expect(
          (o as Offstage).offstage,
          isFalse,
          reason: 'ControlBar should not be offstaged at startup',
        );
      }
    });

    testWidgets('visible at startup (idle + emptyStatePresent)',
        (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(emptyStatePresent: true));
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);

      final offstageList = tester.widgetList(find.byType(Offstage));
      for (final o in offstageList) {
        expect(
          (o as Offstage).offstage,
          isFalse,
          reason: 'ControlBar should not be offstaged even with emptyState',
        );
      }
    });

    testWidgets('buttons interactive at startup (idle + emptyState)',
        (tester) async {
      var fileOpened = false;
      var settingsOpened = false;
      var fullscreenToggled = false;

      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(
        emptyStatePresent: true,
        actions: PlayerActions(
          onOpenFile: () => fileOpened = true,
          onSettings: () => settingsOpened = true,
          onToggleFullscreen: () => fullscreenToggled = true,
        ),
      ));
      await tester.pump();

      // 打开文件按钮
      final openFileBtn = find.byIcon(Icons.folder_open);
      if (openFileBtn.evaluate().isNotEmpty) {
        await tester.tap(openFileBtn);
        await tester.pump();
        expect(fileOpened, isTrue,
            reason: 'Open file button should be tappable at startup');
      }

      // 设置按钮
      final settingsBtn = find.byIcon(Icons.settings);
      if (settingsBtn.evaluate().isNotEmpty) {
        await tester.tap(settingsBtn);
        await tester.pump();
        expect(settingsOpened, isTrue,
            reason: 'Settings button should be tappable at startup');
      }

      // 全屏按钮
      final fsBtn = find.byIcon(Icons.fullscreen);
      if (fsBtn.evaluate().isNotEmpty) {
        await tester.tap(fsBtn);
        await tester.pump();
        expect(fullscreenToggled, isTrue,
            reason: 'Fullscreen button should be tappable at startup');
      }
    });

    testWidgets('FadeTransition opacity is 1.0 at startup', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(emptyStatePresent: true));
      await tester.pump();

      final fades = tester.widgetList(find.byType(FadeTransition));
      expect(fades, isNotEmpty);

      final hasVisible = fades.any((w) => (w as FadeTransition).opacity.value > 0.99);
      expect(hasVisible, isTrue,
          reason: 'FadeTransition should have opacity ~1.0 at startup');
    });
  });
}
