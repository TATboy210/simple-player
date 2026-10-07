import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_settings_content.dart';
import 'package:simple_player_flutter/ui/shared/spin_control.dart';

import '../../helpers/fake_engine.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  testWidgets(
    'two mounted audio panels follow external service delay setters',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final engine = FakeEngine();
      final video = VideoProcessingService(engine);
      final settings = AppSettingsService(
        engine: engine,
        videoProcessing: video,
        store: AppSettingsStore(),
      );
      addTearDown(settings.dispose);
      addTearDown(video.dispose);
      addTearDown(engine.dispose);
      await settings.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: Row(
              children: [
                for (final key in ['window', 'full'])
                  Expanded(
                    child: AudioSettingsContent(
                      key: ValueKey(key),
                      settings: settings,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      settings.setAudioDelayMs(150);
      settings.setSubtitleDelayMs(-100);
      await tester.pump();
      expect(find.text('150 ms'), findsNWidgets(2));
      expect(find.text('-100 ms'), findsNWidgets(2));
      var revisions = 0;
      settings.delayRevision.addListener(() => revisions++);
      // Operate real spin buttons on each mounted instance, not its getter.
      final windowAudio = find
          .descendant(
            of: find.byKey(const ValueKey('window')),
            matching: find.byType(SpinControl),
          )
          .first;
      await tester.tap(
        find.descendant(
          of: windowAudio,
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pump();
      expect(revisions, 1);
      expect(find.text('200 ms'), findsNWidgets(2));
      final fullSubtitle = find
          .descendant(
            of: find.byKey(const ValueKey('full')),
            matching: find.byType(SpinControl),
          )
          .last;
      await tester.tap(
        find.descendant(
          of: fullSubtitle,
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await tester.pump();
      expect(revisions, 2);
      expect(find.text('-150 ms'), findsNWidgets(2));
    },
  );
}
