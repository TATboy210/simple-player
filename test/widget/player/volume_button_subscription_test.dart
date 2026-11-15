// ignore_for_file: no-empty-block
/// VolumeButton 合并订阅后的语义回归 — 自动取消静音只由"音量变化"触发.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';

void main() {
  late ValueNotifier<double> volume;
  late ValueNotifier<bool> muted;
  late int toggles;

  setUp(() {
    volume = ValueNotifier(0.8);
    muted = ValueNotifier(false);
    toggles = 0;
  });

  tearDown(() {
    OsdService.I.hide();
    volume.dispose();
    muted.dispose();
  });

  Widget wrap(Widget button) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: button),
  );

  Widget build() => wrap(
    VolumeButton(
      volume: volume,
      isMuted: muted,
      onToggleMute: () {
        toggles++;
        muted.value = !muted.value;
      },
      onSetVolume: (v) => volume.value = v,
    ),
  );

  testWidgets('muting with volume > 0 does not auto-unmute', (tester) async {
    await tester.pumpWidget(build());
    muted.value = true;
    await tester.pump();
    expect(toggles, 0);
    expect(muted.value, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('raising volume while muted auto-unmutes exactly once', (
    tester,
  ) async {
    muted.value = true;
    volume.value = 0;
    await tester.pumpWidget(build());
    volume.value = 0.4;
    await tester.pump();
    expect(toggles, 1);
    expect(muted.value, isFalse);
    expect(find.byIcon(Icons.volume_down), findsOneWidget);
  });

  testWidgets('swapping sources detaches the old ones', (tester) async {
    await tester.pumpWidget(build());
    final otherVolume = ValueNotifier(0.9);
    final otherMuted = ValueNotifier(false);
    addTearDown(otherVolume.dispose);
    addTearDown(otherMuted.dispose);
    await tester.pumpWidget(
      wrap(
        VolumeButton(
          volume: otherVolume,
          isMuted: otherMuted,
          onToggleMute: () => toggles++,
          onSetVolume: (_) {},
        ),
      ),
    );
    // 旧源变化不得再触发回调或重建.
    muted.value = true;
    volume.value = 0.1;
    await tester.pump();
    expect(toggles, 0);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });
}
