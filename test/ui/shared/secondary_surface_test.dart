import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/about_content.dart';

import '../../helpers/fake_window_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/app_tooltip.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
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
  final surface = find.byType(SecondarySurface);
  final textFinder = find.descendant(of: surface, matching: find.text(label));
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
  final surfaceRect = tester.getRect(surface);
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
  test('disposed binding ignores bind/unbind and releases borrowed source', () {
    final binding = SecondarySurfaceMenuBinding();
    final old = ValueNotifier(false);
    final current = ValueNotifier(true);
    addTearDown(old.dispose);
    addTearDown(current.dispose);
    binding.bind(old);
    binding.bind(current);
    binding.unbind(old);
    expect(binding.source, same(current));
    binding.dispose();
    expect(() => binding.unbind(current), returnsNormally);
    expect(() => binding.bind(old), returnsNormally);
    expect(binding.source, isNull);
    expect(
      current.value,
      isTrue,
    ); // Borrowed sources were not disposed or changed.
  });

  testWidgets(
    'build-phase publication reads current pointer and skips disposal',
    (tester) async {
      final binding = SecondarySurfaceMenuBinding();
      final old = ValueNotifier(false);
      final current = ValueNotifier(true);
      addTearDown(old.dispose);
      addTearDown(current.dispose);
      final observed = <ValueNotifier<bool>?>[];
      binding.addListener(() => observed.add(binding.source));
      await tester.pumpWidget(
        Builder(
          builder: (_) {
            binding.bind(old);
            binding.bind(current);
            binding.unbind(old);
            expect(binding.source, same(current));
            return const SizedBox.shrink();
          },
        ),
      );
      expect(observed, isNotEmpty);
      expect(observed, everyElement(same(current)));
      observed.clear();
      await tester.pumpWidget(
        Builder(
          builder: (_) {
            binding.unbind(current);
            binding.dispose();
            binding.bind(old);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(observed, isEmpty);
      expect(binding.source, isNull);
      expect(tester.takeException(), isNull);
    },
  );
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
          _expectCompleteTooltip(tester, message, scale);
          await mouse.moveTo(Offset.zero);
          await tester.pump();
        }
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'actual auto-hidden bar cancels focused tooltip without replacing button',
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
      actual.focusNode?.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(actual.message ?? ''), findsOneWidget);
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
  testWidgets(
    'finite tooltip has no inaccessible scroll in opaque radius12 surface',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(854, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      const label = 'Open file (O)';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: AppTooltip(
                message: label,
                child: TextButton(
                  focusNode: focus,
                  onPressed: () {},
                  child: const Text('trigger'),
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final surface = find.byType(SecondarySurface);
      expect(surface, findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: surface, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>());
      if (decoration is BoxDecoration) {
        expect(decoration.color, Tokens.bgPanel);
        expect(decoration.color?.a, 1);
        expect(decoration.borderRadius, BorderRadius.circular(12));
        expect(decoration.boxShadow, isNull);
        expect(decoration.gradient, isNull);
      }
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(find.text(label), findsOneWidget);
      expect(
        find.descendant(
          of: surface,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      _expectCompleteTooltip(tester, label, 2);
      final rect = tester.getRect(surface);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(854));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(480));
      expect(focus.hasPrimaryFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
