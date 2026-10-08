import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/time_utils.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import 'package:simple_player_flutter/ui/player/shortcuts_help_dialog.dart';
import 'package:simple_player_flutter/ui/shared/glass_confirm_strip.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// Real dialog/preview fixtures retain native routes and actual render geometry.
Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 2,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: child),
);

/// Validate painted character boxes, not merely retained Text/semantics strings.
void _complete(WidgetTester tester, Finder text, Rect bounds) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.maxLines, isNull);
  expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  expect(boxes, isNotEmpty);
  for (final box in boxes) {
    final rect = box.toRect().shift(paragraph.localToGlobal(Offset.zero));
    expect(bounds.inflate(.01).contains(rect.topLeft), isTrue);
    expect(bounds.inflate(.01).contains(rect.bottomRight), isTrue);
  }
}

void main() {
  setUp(() {});
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'help opaque scroll with visible native exits ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(854, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ShortcutsHelpDialog(),
                ),
                child: const Text('open'),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.backgroundColor, Tokens.bgPanel);
        expect(dialog.elevation, 0);
        expect(
          dialog.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ShortcutsHelpDialog)),
        );
        final close = find.widgetWithText(TextButton, l10n.close);
        expect(close.hitTestable(), findsOneWidget);
        final scroll = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        );
        expect(scroll, findsOneWidget);
        final state = tester.state<ScrollableState>(scroll);
        expect(state.position.maxScrollExtent, greaterThan(0));
        // The actual final localized definition remains reachable by scrolling.
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pump();
        final tail = shortcutDefinitions(l10n).last.$2;
        _complete(tester, find.text(tail), const Rect.fromLTWH(0, 0, 854, 480));
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(ShortcutsHelpDialog), findsNothing);
      },
    );
  }

  for (final exit in ['close', 'barrier']) {
    testWidgets('help preserves native $exit exit', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ShortcutsHelpDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (exit == 'close') {
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ShortcutsHelpDialog)),
        );
        await tester.tap(find.widgetWithText(TextButton, l10n.close));
      } else {
        await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutsHelpDialog), findsNothing);
    });
  }

  for (final exit in ['confirm', 'cancel', 'barrier', 'escape']) {
    testWidgets(
      'confirmation complete scrolling and $exit returns native result',
      (tester) async {
        tester.view.physicalSize = const Size(854, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final message =
            '${List.filled(50, '完整文件名 LongLatinFileName').join(' ')} END';
        bool? result;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await GlassConfirmStrip.show(
                    context,
                    message: message,
                    confirmTooltip: 'remove',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final surface = find.descendant(
          of: find.byType(GlassConfirmStrip),
          matching: find.byType(SecondarySurface),
        );
        expect(surface, findsOneWidget);
        expect(
          find.descendant(of: surface, matching: find.byType(BackdropFilter)),
          findsNothing,
        );
        final text = tester.widget<Text>(find.text(message));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        final scroll = find.descendant(
          of: surface,
          matching: find.byType(Scrollable),
        );
        final state = tester.state<ScrollableState>(scroll);
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pump();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(message),
            matching: find.byType(RichText),
          ),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: message.length - 3,
            extentOffset: message.length,
          ),
        );
        expect(boxes, isNotEmpty);
        final tail = boxes.last.toRect().shift(
          paragraph.localToGlobal(Offset.zero),
        );
        final viewport = tester.getRect(scroll);
        expect(viewport.inflate(.01).contains(tail.topLeft), isTrue);
        expect(viewport.inflate(.01).contains(tail.bottomRight), isTrue);
        expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
        expect(find.byIcon(Icons.delete).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        switch (exit) {
          case 'confirm':
            await tester.tap(find.byIcon(Icons.delete));
          case 'cancel':
            await tester.tap(find.byIcon(Icons.close));
          case 'barrier':
            await tester.tapAt(const Offset(5, 5));
          case 'escape':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tester.pumpAndSettle();
        expect(result, exit == 'confirm');
        expect(find.byType(GlassConfirmStrip), findsNothing);
      },
    );
  }

  testWidgets('preview rebinds retained owner and suppresses inactive route', (
    tester,
  ) async {
    final position = ValueNotifier(0);
    final duration = ValueNotifier(120000);
    final first = ValueNotifier(true);
    final second = ValueNotifier(false);
    final source = ValueNotifier(first);
    final navigator = GlobalKey<NavigatorState>();
    for (final notifier in [position, duration, first, second, source]) {
      addTearDown(notifier.dispose);
    }
    final retained = Center(
      child: SizedBox(
        width: 300,
        height: 24,
        child: ProgressBar(
          position: position,
          duration: duration,
          onSeek: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<ValueNotifier<bool>>(
            valueListenable: source,
            builder: (_, owner, child) => SecondarySurfaceVisibility(
              visibility: owner,
              child: child ?? const SizedBox.shrink(),
            ),
            child: retained,
          ),
        ),
      ),
    );
    final progress = find.byType(ProgressBar);
    final element = tester.element(progress);
    final rect = tester.getRect(progress);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byType(SecondarySurface), findsOneWidget);
    source.value = second;
    await tester.pump();
    await tester.pump();
    expect(find.byType(SecondarySurface, skipOffstage: false), findsNothing);
    first.value = false;
    first.value = true;
    await tester.pump();
    expect(find.byType(SecondarySurface, skipOffstage: false), findsNothing);
    second.value = true;
    await tester.pump();
    await tester.pump();
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byType(SecondarySurface), findsOneWidget);
    expect(tester.element(progress), same(element));
    final dialog = showDialog<void>(
      context: tester.element(progress),
      builder: (_) => const AlertDialog(content: Text('foreign route')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SecondarySurface, skipOffstage: false), findsNothing);
    navigator.currentState?.pop();
    await tester.pumpAndSettle();
    await dialog;
    await mouse.moveTo(const Offset(10, 10));
    await mouse.moveTo(rect.center);
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byType(SecondarySurface), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    // Disposed previews must no longer listen to either borrowed owner source.
    second.value = false;
    first.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'high hours preview paints beyond primary clip within window x$scale',
      (tester) async {
        tester.view.physicalSize = const Size(854, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final position = ValueNotifier<int>(0);
        final duration = ValueNotifier<int>(3600000000000);
        addTearDown(position.dispose);
        addTearDown(duration.dispose);
        await tester.pumpWidget(
          _app(
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 180,
                  height: 24,
                  child: ProgressBar(
                    position: position,
                    duration: duration,
                    onSeek: (_) {},
                  ),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        final bar = tester.getRect(find.byType(ProgressBar));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: bar.center);
        for (final fraction in [.01, .5, .99]) {
          await mouse.moveTo(
            Offset(bar.left + bar.width * fraction, bar.center.dy),
          );
          await tester.pump();
          final text = formatMs((fraction * duration.value).round());
          expect(find.text(text), findsOneWidget); // next frame, no400ms wait
          final surface = find.byType(SecondarySurface);
          expect(surface, findsOneWidget);
          final rect = tester.getRect(surface);
          _complete(tester, find.text(text), rect);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(854));
          expect(rect.bottom, lessThanOrEqualTo(bar.top));
          // An overlay must escape primary clipping; a Text string alone cannot prove it.
          // Portal widgets retain logical inherited ancestry but their render
          // subtree is painted by Overlay. Inspect physical render parents.
          RenderObject? ancestor = tester.renderObject(surface).parent;
          while (ancestor != null) {
            expect(ancestor, isNot(isA<RenderClipRRect>()));
            ancestor = ancestor.parent;
          }
          expect(
            find.descendant(of: surface, matching: find.byType(Scrollable)),
            findsNothing,
          );
          final decoration = tester
              .widget<Container>(
                find
                    .descendant(of: surface, matching: find.byType(Container))
                    .first,
              )
              .decoration;
          expect(decoration, isA<BoxDecoration>());
          if (decoration is BoxDecoration) {
            expect(decoration.color?.a, 1);
            expect(decoration.borderRadius, BorderRadius.circular(12));
            expect(decoration.boxShadow, isNull);
            expect(decoration.border, isNull);
          }
          expect(tester.takeException(), isNull);
        }
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
