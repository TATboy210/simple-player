import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import 'package:simple_player_flutter/ui/shared/glass_confirm_strip.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

/// Each secondary subtree is inspected independently; primary blur is required.
void _secondary(WidgetTester tester, Finder surface) {
  expect(surface, findsWidgets);
  for (final element in surface.evaluate()) {
    final finder = find.byElementPredicate((candidate) => candidate == element);
    final decoration = tester
        .widget<Container>(
          find.descendant(of: finder, matching: find.byType(Container)).first,
        )
        .decoration;
    expect(decoration, isA<BoxDecoration>());
    if (decoration is BoxDecoration) {
      expect(decoration.color, Tokens.bgPanel);
      expect(decoration.color?.a, 1);
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.boxShadow, isNull);
      expect(decoration.gradient, isNull);
    }
    expect(
      find.descendant(of: finder, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  }
}

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  for (final hide in ['owner', 'scheduled']) {
    testWidgets('retained bar preview obeys $hide hide after outside drag', (
      tester,
    ) async {
      final engine = FakeEngine()..state.value = MediaState.playing;
      final video = FakeVideoControlsPort();
      video.player.durationNow = const Duration(minutes: 2);
      final title = ValueNotifier('preview.mkv');
      final mode = ValueNotifier(WindowMode.windowed);
      final resizing = ValueNotifier(false);
      addTearDown(engine.dispose);
      addTearDown(video.dispose);
      addTearDown(title.dispose);
      addTearDown(mode.dispose);
      addTearDown(resizing.dispose);
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
              windowMode: mode,
              resizing: resizing,
            ),
          ),
        ),
      );
      await tester.pump();
      final progress = find.byType(ProgressBar);
      final bar = find.byType(ControlBar);
      final element = tester.element(progress);
      final state = tester.state(progress);
      final barElement = tester.element(bar);
      final focus = FocusManager.instance.primaryFocus;
      final rect = tester.getRect(progress);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.center);
      await mouse.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(find.byType(SecondarySurface), findsOneWidget);
      await mouse.down(rect.center);
      await mouse.moveBy(const Offset(30, 0));
      // Leave the bar physically while retaining the existing drag/hover source.
      await mouse.moveTo(Offset(rect.right + 20, rect.top - 70));
      await mouse.up();
      final target = video.player.lastSeekPosition;
      expect(target, isNotNull);
      if (target != null) video.player.emitPosition(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SecondarySurface), findsOneWidget);
      final owner = SecondarySurfaceVisibility.read(tester.element(progress));
      expect(owner?.value, isTrue);
      if (hide == 'owner') {
        final ownerWidget = tester.widget<SecondarySurfaceOwner>(
          find
              .ancestor(of: bar, matching: find.byType(SecondarySurfaceOwner))
              .first,
        );
        ownerWidget.eligibility?.value = false;
        await tester.pump();
      } else {
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(owner?.value, isFalse);
      // Portal render children bypass Offstage even though logical finders do not.
      expect(find.byType(SecondarySurface, skipOffstage: false), findsNothing);
      expect(
        tester.element(find.byType(ProgressBar, skipOffstage: false)),
        same(element),
      );
      expect(
        tester.state(find.byType(ProgressBar, skipOffstage: false)),
        same(state),
      );
      expect(
        tester.element(find.byType(ControlBar, skipOffstage: false)),
        same(barElement),
      );
      expect(FocusManager.instance.primaryFocus, same(focus));
      // Keep the primary CustomPaint cache intact while the hidden stream moves.
      resizing.value = true;
      await tester.pump();
      final paint = find.descendant(
        of: find.byType(ProgressBar, skipOffstage: false),
        matching: find.byType(CustomPaint, skipOffstage: false),
      );
      final cachedPaint = tester.widget<CustomPaint>(paint);
      video.player.emitPosition(const Duration(seconds: 30));
      await tester.pump();
      expect(tester.widget<CustomPaint>(paint), same(cachedPaint));
      resizing.value = false;
      video.player.emitPlaying(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(owner?.value, isTrue);
      // Actual new hover supplies the new fraction; no new popup clock/focus.
      await mouse.moveTo(const Offset(10, 10));
      await mouse.moveTo(rect.center);
      await mouse.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(find.byType(SecondarySurface), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'composed primary bar retains blur and elements across preview OSD menu confirmation resize',
    (tester) async {
      tester.view.physicalSize = const Size(854, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = FakeEngine();
      final video = FakeVideoControlsPort();
      final title = ValueNotifier<String>('identity.mkv');
      final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
      final settings = ValueNotifier<bool>(true);
      video.player.durationNow = const Duration(hours: 999999);
      engine.duration.value = const Duration(hours: 999999).inMilliseconds;
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
              windowMode: mode,
              settingsVisible: settings,
            ),
          ),
        ),
      );
      await tester.pump();
      final bar = find.byType(ControlBar);
      final progress = find.byType(ProgressBar);
      final barElement = tester.element(bar);
      final progressElement = tester.element(progress);
      final progressState = tester.state(progress);
      final settingsElement = tester.element(find.byType(SettingsPanel));
      final filters = find.descendant(
        of: bar,
        matching: find.byType(BackdropFilter),
      );
      final originalFilters = filters.evaluate().length;
      expect(originalFilters, greaterThan(0));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final rect = tester.getRect(progress);
      await mouse.addPointer(location: rect.center);
      await mouse.moveBy(const Offset(1, 0));
      await tester.pump();
      _secondary(tester, find.byType(SecondarySurface));
      OsdService.I.show('status');
      await tester.pump();
      _secondary(tester, find.byType(SecondarySurface));
      final context = tester.element(bar);
      final menu = GlassMenu.show(
        context,
        position: const Offset(100, 100),
        items: const [GlassMenuItem(Icons.copy, 'Action', value: 'action')],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _secondary(tester, find.byType(SecondarySurface));
      await tester.tap(find.text('Action'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await menu;
      final confirmation = GlassConfirmStrip.show(
        context,
        message: 'Remove complete filename?',
        confirmTooltip: 'remove',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _secondary(
        tester,
        find.descendant(
          of: find.byType(GlassConfirmStrip),
          matching: find.byType(SecondarySurface),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(GlassConfirmStrip),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await confirmation, isFalse);
      tester.view.physicalSize = const Size(1000, 600);
      await tester.pump();
      expect(tester.element(bar), same(barElement));
      expect(tester.element(progress), same(progressElement));
      expect(tester.state(progress), same(progressState));
      expect(tester.element(find.byType(SettingsPanel)), same(settingsElement));
      expect(filters.evaluate().length, originalFilters);
      expect(tester.takeException(), isNull);
      OsdService.I.hide();
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      video.dispose();
      engine.dispose();
      title.dispose();
      mode.dispose();
      settings.dispose();
    },
  );
}
