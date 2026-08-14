import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

void main() {
  testWidgets('局部状态变化不会重建 PlayerVideoControls 外层', (tester) async {
    final engine = FakeEngine();
    final video = FakeVideoControlsPort();
    final title = ValueNotifier<String>('first.mp4');
    final resizing = ValueNotifier<bool>(false);
    final openFileEnabled = ValueNotifier<bool>(true);
    var builds = 0;

    addTearDown(() {
      title.dispose();
      resizing.dispose();
      openFileEnabled.dispose();
      video.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlayerVideoControls(
            video: video,
            engine: engine,
            actions: const PlayerActions(),
            currentFileName: title,
            openFileEnabled: openFileEnabled,
            resizing: resizing,
            onBuild: () => builds += 1,
          ),
        ),
      ),
    );
    await tester.pump();
    final initialBuilds = builds;

    title.value = 'second.mp4';
    resizing.value = true;
    engine.play();
    video.player.emitPosition(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(builds, initialBuilds);
    expect(find.text('second.mp4'), findsOneWidget);
  });
}
