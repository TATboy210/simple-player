import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/shared/app_tooltip.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/about_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_window_service.dart';
import '../../helpers/fake_video_controls.dart';

import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  testWidgets(
    'actual titlebar outside controls borrows screen menu session at root',
    (tester) async {
      final engine = FakeEngine();
      final window = FakeWindowService();
      final controller = PlaybackController(engine: engine);
      final video = FakeVideoControlsPort();
      addTearDown(engine.dispose);
      addTearDown(window.dispose);
      addTearDown(controller.dispose);
      addTearDown(video.dispose);
      var surfaces = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) =>
              SecondarySurfaceMenuRoot(child: child ?? const SizedBox.shrink()),
          home: PlayerScreen(
            engine: engine,
            controller: controller,
            windowService: window,
            videoSurfaceBuilder: (_) {
              surfaces++;
              return const SizedBox.expand();
            },
            testVideoControls: video,
          ),
        ),
      );
      await tester.pump();
      final controls = tester.widget<WorkspaceMenuScope>(
        find.byType(WorkspaceMenuScope),
      );
      final title = find.byKey(const ValueKey('titlebar-minimize'));
      final ink = tester.widget<InkWell>(
        find.descendant(of: title, matching: find.byType(InkWell)),
      );
      final focus = Focus.of(
        tester.element(find.descendant(of: title, matching: find.byType(Icon))),
      );
      expect(ink.onTap, isNotNull);
      expect(focus, isNotNull);
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 399));
      expect(find.text('Minimize'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Minimize'), findsOneWidget);
      final token = controls.session.open(
        owner: Object(),
        cancel: () {},
        isCurrent: () => true,
      );
      await tester.pump();
      expect(find.text('Minimize'), findsNothing);
      expect(surfaces, 1);
      controls.session.finish(token);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Minimize'), findsOneWidget);
      window.mode.value = WindowMode.fullscreen;
      await tester.pump();
      await tester
          .pump(); // Overlay removal during owner build flushes next frame.
      expect(find.text('Minimize'), findsNothing);
      expect(surfaces, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cached settings About tooltip cancels on L1 exit and panel hide',
    (tester) async {
      final session = SettingsPanelSession()..navigate('about', true);
      addTearDown(session.dispose);
      Widget subject(bool visible) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SettingsPanel(
              visible: visible,
              session: session,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(true));
      await tester.pump(const Duration(milliseconds: 400));
      final tooltip = find
          .descendant(
            of: find.byType(AboutContent),
            matching: find.byType(AppTooltip),
          )
          .first;
      final original = tester.element(tooltip);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(tooltip));
      await tester.pump(const Duration(milliseconds: 400));
      final message = tester.widget<AppTooltip>(tooltip).message;
      expect(find.text(message ?? ''), findsOneWidget);
      session.navigate('about', false);
      await tester.pump();
      await tester.pump(); // Entry is removed synchronously; overlay repaint is deferred.
      expect(find.text(message ?? ''), findsNothing);
      expect(
        tester.element(
          find
              .descendant(
                of: find.byType(AboutContent, skipOffstage: false),
                matching: find.byType(AppTooltip, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        ),
        same(original),
      );
      await tester.pumpWidget(subject(false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(message ?? ''), findsNothing);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('actual SpeedButton descendant focus only tips its own segment', (
    tester,
  ) async {
    final rate = ValueNotifier(1.0);
    addTearDown(rate.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SpeedButton(rate: rate, onSetRate: (_) {}),
          ),
        ),
      ),
    );
    final tip = find.byType(AppTooltip).first;
    final focus = Focus.of(
      tester.element(find.descendant(of: tip, matching: find.byType(Icon))),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    expect(
      find.text(tester.widget<AppTooltip>(tip).message ?? ''),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.text(tester.widget<AppTooltip>(tip).message ?? ''),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('implicit focus lookup survives same-frame control replacement', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget subject(String label, {FocusNode? node}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppTooltip(
            key: ValueKey(label),
            message: '$label tip',
            child: TextButton(
              focusNode: node,
              onPressed: () {},
              child: Text(label),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(subject('old', node: focus));
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('old tip'), findsOneWidget);
    // primaryFocus is updated after build; the new tooltip must not inspect
    // ancestors of the old, already deactivated control in this frame.
    await tester.pumpWidget(subject('new'));
    expect(tester.takeException(), isNull);
    expect(find.text('new'), findsOneWidget);
    expect(tester.getSize(find.text('new')).height, lessThan(100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('old tip'), findsNothing);
    expect(find.text('new tip'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final elapsed in [200, 400]) {
    testWidgets('unmount at ${elapsed}ms cancels exact entry and stale delay', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTooltip(
              message: 'old',
              child: TextButton(
                focusNode: focus,
                onPressed: () {},
                child: const Text('button'),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.pump(Duration(milliseconds: elapsed));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('replacement'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('old'), findsNothing);
      expect(find.text('replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final glass in [false, true]) {
    for (final keyboard in [false, true]) {
      testWidgets(
        'actual ${glass ? 'GlassButton' : 'plain'} ${keyboard ? 'focus' : 'mouse'} waits 399/400ms',
        (tester) async {
          final focus = FocusNode();
          addTearDown(focus.dispose);
          final control = glass
              ? GlassButton.iconOnly(
                  icon: Icons.play_arrow,
                  tooltip: 'tip',
                  focusNode: focus,
                  onPressed: () {},
                )
              : AppTooltip(
                  message: 'tip',
                  child: TextButton(
                    focusNode: focus,
                    onPressed: () {},
                    child: const Text('plain'),
                  ),
                );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: Center(child: control)),
            ),
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          if (keyboard) {
            focus.requestFocus();
            await tester.pump();
          } else {
            await mouse.addPointer(
              location: tester.getCenter(find.byWidget(control)),
            );
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 399));
          expect(find.text('tip'), findsNothing);
          await tester.pump(const Duration(milliseconds: 1));
          expect(find.text('tip'), findsOneWidget);
          expect(focus.hasFocus, keyboard);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('pointer exit retains actual focus eligibility', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassButton.iconOnly(
              icon: Icons.play_arrow,
              tooltip: 'tip',
              focusNode: focus,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(GlassButton)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('tip'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final visible in [false, true]) {
    testWidgets(
      'owned menu cancels ${visible ? 'visible' : 'pending'} tooltip and close starts fresh',
      (tester) async {
        final menus = WorkspaceMenuSession();
        final focus = FocusNode();
        addTearDown(menus.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkspaceMenuScope(
                session: menus,
                onEscape: () {},
                child: Center(
                  child: GlassButton.iconOnly(
                    icon: Icons.play_arrow,
                    tooltip: 'tip',
                    focusNode: focus,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        await tester.pump(Duration(milliseconds: visible ? 400 : 200));
        final token = menus.open(
          owner: Object(),
          cancel: () {},
          isCurrent: () => true,
        );
        await tester.pump();
        expect(find.text('tip'), findsNothing);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('tip'), findsNothing);
        menus.finish(token);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 399));
        expect(find.text('tip'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('tip'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('retained owner hide and replacement invalidate obsolete delay', (
    tester,
  ) async {
    final eligible = ValueNotifier(true);
    final focus = FocusNode();
    addTearDown(eligible.dispose);
    addTearDown(focus.dispose);
    Widget subject(String text) => MaterialApp(
      home: Scaffold(
        body: SecondarySurfaceOwner(
          visible: true,
          eligibility: eligible,
          child: Center(
            child: GlassButton.iconOnly(
              icon: Icons.play_arrow,
              tooltip: text,
              focusNode: focus,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(subject('old'));
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    eligible.value = false;
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('old'), findsNothing);
    eligible.value = true;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(subject('new'));
    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('new'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('new'), findsOneWidget);
    eligible.value = false;
    await tester.pump();
    expect(find.text('new'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GlassButton has one Tab stop and activates once with primary glass retained',
    (tester) async {
      final first = FocusNode();
      final next = FocusNode();
      addTearDown(first.dispose);
      addTearDown(next.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                GlassButton(
                  icon: Icons.play_arrow,
                  label: 'Play',
                  tooltip: 'tip',
                  focusNode: first,
                  onPressed: () => calls++,
                ),
                TextButton(
                  focusNode: next,
                  onPressed: () {},
                  child: const Text('next'),
                ),
              ],
            ),
          ),
        ),
      );
      final glass = tester.element(find.byType(GlassContainer));
      first.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('tip'), findsOneWidget);
      expect(tester.element(find.byType(GlassContainer)), same(glass));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(next.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
