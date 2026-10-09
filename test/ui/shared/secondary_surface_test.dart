import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/about_content.dart';

import '../../helpers/fake_window_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/app_tooltip.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/modal_hold_observer.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

/// Check natural height and final-character boxes, not merely Text presence.
void _expectCompleteTooltip(WidgetTester tester, String label, double scale) {
  final textFinder = find.text(label);
  final text = tester.widget<Text>(textFinder);
  final rich = find.descendant(of: textFinder, matching: find.byType(RichText));
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  expect(paragraph.textScaler.scale(10), scale * 10);
  expect(text.maxLines, isNull);
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  expect(paragraph.size.height, closeTo(painter.height, 0.01));
  painter.dispose();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: label.length - 1, extentOffset: label.length),
  );
  expect(boxes, isNotEmpty);
  final surfaceRect = const Rect.fromLTWH(0, 0, 854, 480);
  for (final box in boxes) {
    final rect = box.toRect().shift(paragraph.localToGlobal(Offset.zero));
    expect(surfaceRect.contains(rect.topLeft), isTrue);
    expect(surfaceRect.contains(rect.bottomRight), isTrue);
    expect(rect.bottom, lessThanOrEqualTo(480));
    expect(rect.right, lessThanOrEqualTo(854));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.left, greaterThanOrEqualTo(0));
  }
}

void main() {
  for (final locale in ['en', 'zh', 'ko', 'ja']) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('real tooltip corpus $locale overlay scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(854, 480);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final window = FakeWindowService();
        final rate = ValueNotifier(1.0);
        addTearDown(window.dispose);
        addTearDown(rate.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Wrap Navigator AND its Overlay, not only the route body.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    CustomTitleBar(windowService: window),
                    GlassButton.iconOnly(
                      icon: Icons.folder_open,
                      tooltip: AppLocalizations.of(context).openFile,
                      onPressed: () {},
                    ),
                    SpeedButton(rate: rate, onSetRate: (_) {}),
                    const Expanded(child: AboutContent()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final tips = find.byType(AppTooltip);
        // Four title controls, one GlassButton, three speed segments, four brands.
        expect(tips, findsNWidgets(12));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        for (final tip in tips.evaluate().toList()) {
          final target = find.byWidget(tip.widget);
          final message = tester.widget<AppTooltip>(target).message ?? '';
          expect(message, isNotEmpty);
          await mouse.moveTo(tester.getCenter(target));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 200));
          _expectCompleteTooltip(tester, message, scale);
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
        }
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'actual auto-hidden bar preserves control identity without focused tooltip',
    (tester) async {
      KernelLoggerImpl.resetForTesting();
      KernelLoggerImpl.init();
      final engine = FakeEngine();
      final video = FakeVideoControlsPort();
      final title = ValueNotifier('movie.mp4');
      final mode = ValueNotifier(WindowMode.windowed);
      addTearDown(engine.dispose);
      addTearDown(video.dispose);
      addTearDown(title.dispose);
      addTearDown(mode.dispose);
      await engine.open('movie.mp4');
      expect(ModalHoldObserver.openModalCount.value, 0);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerVideoControls(
              video: video,
              engine: engine,
              actions: PlayerActions(onOpenFile: () {}),
              currentFileName: title,
              windowMode: mode,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // Finish startup port emissions.
      final button = find.byWidgetPredicate(
        (widget) => widget is GlassButton && widget.tooltip == 'Open file (O)',
      );
      final target = button.evaluate().isNotEmpty
          ? button
          : find
                .byWidgetPredicate(
                  (widget) =>
                      widget is GlassButton && widget.icon == Icons.folder_open,
                )
                .first;
      final element = tester.element(target);
      final tooltip = find.descendant(
        of: target,
        matching: find.byType(AppTooltip),
      );
      final actual = tester.widget<AppTooltip>(tooltip);
      tester.widget<GlassButton>(target).focusNode?.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(actual.message ?? ''),
        findsNothing,
        reason: 'native tooltip does not react to focus',
      );
      // Drive the actual borrowed AutoHide.visible signal, not a fake scope.
      // AutoHide's scheduling itself remains covered by its existing unit tests.
      final visibility = tester
          .widget<SecondarySurfaceOwner>(
            find
                .ancestor(
                  of: target,
                  matching: find.byType(SecondarySurfaceOwner),
                )
                .first,
          )
          .eligibility;
      expect(visibility, isNotNull);
      visibility?.value = false;
      await tester.pump();
      await tester.pump();
      final retainedTooltip = find.descendant(
        of: find.byWidgetPredicate(
          (widget) => identical(widget, element.widget),
          skipOffstage: false,
        ),
        matching: find.byType(AppTooltip, skipOffstage: false),
        skipOffstage: false,
      );
      final owner = SecondarySurfaceVisibility.read(
        tester.element(retainedTooltip),
      );
      expect(owner?.value, isFalse, reason: 'actual auto-hide completed');
      expect(find.text(actual.message ?? ''), findsNothing);
      expect(
        tester.element(
          find.byWidgetPredicate(
            (widget) => identical(widget, element.widget),
            skipOffstage: false,
          ),
        ),
        same(element),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
