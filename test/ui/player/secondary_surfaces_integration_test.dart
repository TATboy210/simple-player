import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_card_host.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';

/// Existing fixed OSD producer strings; raw reporter.message is not bounded.
List<String> _producerSummaries(AppLocalizations l10n) => [
  l10n.mute,
  l10n.errorCardCopied,
  l10n.errorCardCopyFailed,
  l10n.errorCardLogUnavailable,
  l10n.errorCardLogOpened,
  l10n.errorCardOpenLogFailed,
  '100%',
  '0.25x',
];

/// Prove every laid-out character/line is inside the bubble and live window.
void _expectCompleteGeometry(
  WidgetTester tester,
  String summary,
  Locale locale,
  double scale,
) {
  final overlay = find.byType(OsdOverlay);
  final text = find.descendant(of: overlay, matching: find.text(summary));
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  final surface = find.descendant(
    of: overlay,
    matching: find.byType(SecondarySurface),
  );
  final bubble = tester.getRect(surface);
  final slot = tester.getRect(overlay);
  final bounds = Offset.zero & const Size(854, 480);
  final painted = paragraph.localToGlobal(Offset.zero) & paragraph.size;
  final selection = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: summary.length),
  );
  expect(selection, isNotEmpty);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.maxLines, isNull);
  expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
  expect(paragraph.text.toPlainText(), summary);
  expect(
    paragraph.textScaler.scale(Tokens.fontTitle),
    closeTo(Tokens.fontTitle * scale, .001),
  );
  // Natural height is independent of the render box: catch partial layout/clip
  // even when the complete String still exists in Text or its semantics.
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  expect(paragraph.size.height, closeTo(painter.height, .01));
  painter.dispose();
  for (final rect in [
    bubble,
    painted,
    ...selection.map(
      (box) => box.toRect().shift(paragraph.localToGlobal(Offset.zero)),
    ),
  ]) {
    expect(
      bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight),
      isTrue,
      reason: '$summary outside window: $rect',
    );
    expect(
      slot.inflate(.01).contains(rect.topLeft) &&
          slot.inflate(.01).contains(rect.bottomRight),
      isTrue,
    );
  }
  expect(
    bubble.inflate(.01).contains(painted.topLeft) &&
        bubble.inflate(.01).contains(painted.bottomRight),
    isTrue,
  );
  expect(
    tester
        .getRect(
          find.descendant(
            of: overlay,
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .bottom,
    lessThanOrEqualTo(bubble.bottom),
  );
  // No inaccessible scroll viewport is permitted under pointer transparency.
  expect(
    find.descendant(of: overlay, matching: find.byType(Scrollable)),
    findsNothing,
  );
  expect(
    find.descendant(of: overlay, matching: find.byType(SingleChildScrollView)),
    findsNothing,
  );
  expect(tester.takeException(), isNull);
  // Raw geometry is retained in the verification log, not inferred from Text.
  debugPrint(
    'OSD_GEOMETRY ${locale.languageCode} scale=$scale '
    'summary="$summary" paragraph=$painted bubble=$bubble slot=$slot '
    'selectionLines=${selection.length}',
  );
}

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  testWidgets('real controls mount opaque bottom feedback over open settings', (
    tester,
  ) async {
    final engine = FakeEngine();
    final video = FakeVideoControlsPort();
    final title = ValueNotifier<String>('');
    final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
    final settings = ValueNotifier<bool>(true);
    final resizing = ValueNotifier<bool>(false);
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
            resizing: resizing,
          ),
        ),
      ),
    );
    OsdService.I.show('warning summary', priority: OsdPriority.warning);
    OsdService.I.show('volume status', icon: Icons.volume_up, progress: .4);
    await tester.pump();
    expect(find.text('warning summary'), findsOneWidget);
    expect(find.text('volume status'), findsNothing);
    final surface = find.descendant(
      of: find.byType(OsdOverlay),
      matching: find.byType(SecondarySurface),
    );
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
      expect(decoration.gradient, isNull);
      expect(decoration.boxShadow, isNull);
    }
    expect(
      find.descendant(of: surface, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    expect(
      find.descendant(of: surface, matching: find.byType(Focus)),
      findsNothing,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OsdOverlay),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    final bubble = tester.getRect(surface);
    final controls = tester.getRect(find.byType(PlayerVideoControls));
    expect(bubble.center.dx, closeTo(controls.center.dx, 1));
    expect(
      bubble.bottom,
      closeTo(
        controls.bottom -
            Tokens.controlBarMarginBottom -
            Tokens.controlBarHeight -
            Tokens.spMd,
        1,
      ),
    );
    resizing.value = true;
    OsdService.I.show('updated warning', priority: OsdPriority.warning);
    await tester.pump();
    expect(find.text('updated warning'), findsOneWidget);
    expect(find.text('warning summary'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(OsdService.I.message.value?.text, 'updated warning');
    OsdService.I.hide();
    video.dispose();
    engine.dispose();
    title.dispose();
    mode.dispose();
    settings.dispose();
    resizing.dispose();
  });

  testWidgets(
    'host retains arbitrary warnings and action feedback uses deadlines',
    (tester) async {
      await ErrorReporterImpl.resetForTesting();
      ErrorCaptureSnapshot.I.resetForTesting();
      ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
      var now = Duration.zero;
      final service = OsdService(now: () => now);
      addTearDown(service.dispose);
      addTearDown(ErrorReporterImpl.resetForTesting);
      tester.view.physicalSize = const Size(854, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: Tokens.errorCardExpandedMaxWidth,
                    height: 300,
                    child: ErrorCardHost(
                      osdService: service,
                      logExplorer: (_) async {},
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: OsdOverlay(service: service),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      for (final code in [null, 'unrecognized:code']) {
        final report = ErrorReport(
          eventId: 'warning-$code',
          source: ErrorSource.playerEngine,
          severity: ErrorSeverity.warning,
          firstOccurredAt: DateTime.utc(2026),
          lastOccurredAt: DateTime.utc(2026),
          errorType: 'SyntheticWarning',
          playerErrorCode: code,
          message: List.filled(40, 'Complete diagnostic reason').join(' '),
          rawStackTrace: '#0 original retained stack',
          mediaPath: null,
          occurrenceCount: 1,
        );
        var advances = 0;
        void observe() => advances++;
        ErrorReporterImpl.I.presentation.addListener(observe);
        ErrorReporterImpl.I.presentation.value = ErrorPresentationState(
          current: report,
          pendingCount: 0,
          isReady: true,
        );
        await tester.pump();
        expect(find.byType(ErrorCard), findsOneWidget);
        expect(ErrorCaptureSnapshot.I.reports.value.single, same(report));
        expect(service.message.value, isNull);
        expect(advances, 1);
        final merged = report.copyWith(occurrenceCount: 2);
        ErrorCaptureSnapshot.I.record(merged, ReportAcceptance.merged);
        ErrorReporterImpl.I.presentation.value = ErrorPresentationState(
          current: merged,
          pendingCount: 0,
          isReady: true,
        );
        await tester.pump();
        expect(ErrorCaptureSnapshot.I.reports.value, hasLength(1));
        expect(ErrorCaptureSnapshot.I.reports.value.single.occurrenceCount, 2);
        expect(service.message.value, isNull);
        expect(tester.takeException(), isNull);
        final surface = find.descendant(
          of: find.byType(ErrorCard),
          matching: find.byType(SecondarySurface),
        );
        expect(surface, findsOneWidget);
        expect(
          find.descendant(of: surface, matching: find.byType(BackdropFilter)),
          findsNothing,
        );
        final decoration = tester
            .widget<Container>(
              find
                  .descendant(of: surface, matching: find.byType(Container))
                  .first,
            )
            .decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.color, Tokens.bgPanel);
          expect(
            decoration.borderRadius,
            BorderRadius.circular(Tokens.secondarySurfaceRadius),
          );
          expect(decoration.boxShadow, isNull);
        }
        // Whole-card scroll makes full message and existing actions reachable.
        final scroll = find
            .descendant(
              of: find.byType(ErrorCard),
              matching: find.byType(Scrollable),
            )
            .first;
        final state = tester.state<ScrollableState>(scroll);
        state.position.jumpTo(0);
        await tester.pump();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        await tester.tap(find.byKey(const ValueKey('error-card-copy')));
        await tester.pump();
        expect(service.message.value?.priority, OsdPriority.success);
        expect(
          service.snapshot.value.current?.expiresAt,
          const Duration(milliseconds: 1600),
        );
        now = const Duration(milliseconds: 500);
        await tester.tap(find.byKey(const ValueKey('error-card-open-log')));
        await tester.pump();
        expect(service.message.value?.priority, OsdPriority.warning);
        expect(
          service.snapshot.value.current?.expiresAt,
          now + const Duration(milliseconds: 4000),
        );
        service.show('volume', priority: OsdPriority.status);
        expect(service.message.value?.text, isNot('volume'));
        await tester.tap(find.byKey(const ValueKey('error-card-close')));
        await tester.pump();
        expect(advances, 3); // Two publications, exactly one manual advance.
        expect(ErrorCaptureSnapshot.I.reports.value, isEmpty);
        ErrorReporterImpl.I.presentation.removeListener(observe);
        service.hide();
        now = Duration.zero;
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final scale in [1.5, 2.0]) {
      testWidgets(
        'complete producer summaries ${locale.languageCode} x$scale',
        (tester) async {
          tester.view.physicalSize = const Size(854, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final engine = FakeEngine();
          final video = FakeVideoControlsPort();
          final title = ValueNotifier<String>('');
          final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: Scaffold(
                body: PlayerVideoControls(
                  video: video,
                  engine: engine,
                  actions: const PlayerActions(),
                  currentFileName: title,
                  windowMode: mode,
                ),
              ),
            ),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(OsdOverlay)),
          );
          // These are the actual bounded copy/log/mute producers, not raw reports.
          for (final summary in _producerSummaries(l10n)) {
            OsdService.I.show(summary, icon: Icons.warning, progress: .8);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            _expectCompleteGeometry(tester, summary, locale, scale);
          }
          OsdService.I.hide();
          await tester.pumpWidget(const SizedBox.shrink());
          video.dispose();
          engine.dispose();
          title.dispose();
          mode.dispose();
        },
      );
    }
  }
}
