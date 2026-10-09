import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';

/// Manual delivery lets stale service callbacks race real ticker completion.
class _RaceScheduler {
  final jobs = <_RaceJob>[];
  int maxOutstanding = 0;
  int get outstanding => jobs.where((job) => !job.canceled).length;

  VoidCallback schedule(Duration delay, VoidCallback fire) {
    final job = _RaceJob(fire);
    jobs.add(job);
    if (outstanding > maxOutstanding) maxOutstanding = outstanding;
    return () => job.canceled = true;
  }
}

class _RaceJob {
  _RaceJob(this.fire);
  final VoidCallback fire;
  bool canceled = false;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  var service = OsdService();
  setUp(() {
    service.dispose();
    // Inject the fake test clock: production Stopwatch must not follow wall time.
    DateTime? start;
    service = OsdService(
      now: () {
        final now = binding.inTest ? binding.clock.now() : DateTime.now();
        start ??= now;
        return now.difference(start ?? now);
      },
    );
  });
  tearDown(() => service.dispose());

  group('OsdMessage', () {
    test('holds text, icon, and progress', () {
      const msg = OsdMessage(
        text: '75%',
        icon: Icons.volume_up,
        progress: 0.75,
      );

      expect(msg.text, '75%');
      expect(msg.icon, Icons.volume_up);
      expect(msg.progress, 0.75);
    });

    test('icon and progress are optional', () {
      const msg = OsdMessage(text: 'Hello');

      expect(msg.text, 'Hello');
      expect(msg.icon, isNull);
      expect(msg.progress, isNull);
    });
  });

  group('OsdService', () {
    test('show() sets message and visible', () {
      service.show('50%', progress: 0.5);

      expect(service.visible.value, isTrue);
      expect(service.message.value, isNotNull);
      expect(service.message.value!.text, '50%');
      expect(service.message.value!.progress, 0.5);
      service.hide();
    });

    test('show() with icon', () {
      service.show('Muted', icon: Icons.volume_off);

      expect(service.message.value!.icon, Icons.volume_off);
      service.hide();
    });

    test('hide() clears message and visible', () {
      service.show('test');
      expect(service.visible.value, isTrue);

      service.hide();

      expect(service.visible.value, isFalse);
      expect(service.message.value, isNull);
    });
  });

  group('OsdOverlay widget', () {
    for (final order in [
      ['timer', 'fade', 'show'],
      ['timer', 'show', 'fade'],
      ['fade', 'timer', 'show'],
      ['fade', 'show', 'timer'],
      ['show', 'timer', 'fade'],
      ['show', 'fade', 'timer'],
    ]) {
      testWidgets('same 1600ms timer/fade/show ${order.join("-")}', (
        tester,
      ) async {
        final scheduler = _RaceScheduler();
        final start = binding.clock.now();
        final local = OsdService(
          now: () => binding.clock.now().difference(start),
          schedule: scheduler.schedule,
        );
        await tester.pumpWidget(MaterialApp(home: OsdOverlay(service: local)));
        local.show('old', priority: OsdPriority.success);
        local.show('overdue pending'); // Expires at 1200, never resurfaces.
        final staleTimer = scheduler.jobs.last;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 1200));
        local.hide();
        await tester.pump(); // Exit starts at 1400; completion is due at 1600.
        await tester.pump(const Duration(milliseconds: 100));
        final beforeRace = tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value;
        expect(beforeRace, greaterThan(0));
        expect(beforeRace, lessThan(1));
        // Advance the fake clock WITHOUT delivering a frame or timer callback.
        // Each permutation below then runs at precisely the same clock instant.
        if (binding is AutomatedTestWidgetsFlutterBinding) {
          binding.elapseBlocking(const Duration(milliseconds: 100));
        } else {
          fail('This deterministic race requires the automated fake binding');
        }
        for (final event in order) {
          switch (event) {
            case 'timer':
              staleTimer.fire();
            case 'fade':
              await tester.pump();
            case 'show':
              local.show('new', icon: Icons.volume_up, progress: .8);
          }
          expect(binding.clock.now().difference(start).inMilliseconds, 1600);
        }
        await tester.pump();
        expect(local.message.value?.text, 'new');
        expect(local.snapshot.value.pending, isNull);
        expect(local.snapshot.value.current?.expiresAt.inMilliseconds, 2800);
        expect(find.text('new'), findsOneWidget);
        expect(find.text('old'), findsNothing);
        expect(find.text('overdue pending'), findsNothing);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .8,
        );
        // Inspect the continuous timeline, not an invented 1ms completion.
        final opacity = tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value;
        expect(opacity, inInclusiveRange(0.0, 1.0));
        await tester.pump(const Duration(milliseconds: 100));
        final midway = tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value;
        expect(midway, greaterThan(opacity));
        expect(midway, lessThan(1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester
              .widget<FadeTransition>(find.byType(FadeTransition).last)
              .opacity
              .value,
          1,
        );
        expect(find.text('new'), findsOneWidget);
        expect(scheduler.maxOutstanding, 1);
        expect(scheduler.outstanding, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        local.dispose();
        expect(scheduler.outstanding, 0);
      });
    }
    for (final completionFirst in [true, false]) {
      testWidgets('mid-exit reversal completionFirst=$completionFirst', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OsdOverlay(service: service)),
          ),
        );
        service.show('old');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        service.hide();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final before = tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value;
        expect(before, greaterThan(0));
        expect(before, lessThan(1));
        if (completionFirst) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        service.show('new', icon: Icons.volume_up, progress: .8);
        await tester.pump();
        expect(find.text('old'), findsNothing);
        expect(find.text('new'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .8,
        );
        await tester.pump(const Duration(milliseconds: 1));
        final reversed = tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value;
        expect(reversed, lessThan(1));
        if (!completionFirst) expect(reversed, greaterThanOrEqualTo(before));
        await tester.pump(const Duration(milliseconds: 199));
        expect(
          tester
              .widget<FadeTransition>(find.byType(FadeTransition).last)
              .opacity
              .value,
          1,
        );
        expect(find.text('new'), findsOneWidget);
        service.hide();
      });
    }

    testWidgets('inactive route detaches and recreation borrows live state', (
      tester,
    ) async {
      final active = ValueNotifier<bool>(true);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, value, _) => TickerMode(
              enabled: value,
              child: OsdOverlay(service: service),
            ),
          ),
        ),
      );
      service.show('first');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      active.value = false;
      await tester.pump();
      service.show('live second');
      await tester.pump();
      expect(find.text('first'), findsOneWidget);
      expect(find.text('live second'), findsNothing);
      active.value = true;
      await tester.pump();
      expect(find.text('live second'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(service.message.value?.text, 'live second');
      await tester.pumpWidget(MaterialApp(home: OsdOverlay(service: service)));
      expect(find.text('live second'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.hide();
      active.dispose();
    });
    testWidgets('renders SizedBox.shrink when no message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsdOverlay(service: service)),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders text when message is shown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsdOverlay(service: service)),
        ),
      );

      service.show('75%');
      await tester.pump();

      expect(find.text('75%'), findsOneWidget);

      // Let the hide timer fire to avoid pending timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders icon when message has icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsdOverlay(service: service)),
        ),
      );

      service.show('Muted', icon: Icons.volume_off);
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders progress bar when message has progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsdOverlay(service: service)),
        ),
      );

      service.show('50%', progress: 0.5);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('retains outgoing message until fade completes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsdOverlay(service: service)),
        ),
      );

      service.show('test');
      await tester.pump();
      expect(find.text('test'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      service.hide();
      await tester.pump();
      expect(find.text('test'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('test'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester
          .pump(); // Render the payload cleanup queued by ticker completion.
      expect(
        find.descendant(
          of: find.byType(OsdOverlay),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(find.text('test'), findsNothing);
    });

    // ── Resize freeze tests ──

    testWidgets('renders with resizing parameter', (tester) async {
      final resizing = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsdOverlay(service: service, resizing: resizing),
          ),
        ),
      );

      expect(find.byType(OsdOverlay), findsOneWidget);
      resizing.dispose();
    });

    testWidgets('updates immediately and expires while resizing', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsdOverlay(service: service, resizing: resizing),
          ),
        ),
      );

      // Show a message first so there is something to cache
      service.show('before');
      await tester.pump();
      expect(find.text('before'), findsOneWidget);

      // Start resizing — cached child should be returned
      resizing.value = true;
      await tester.pump();

      // Change message during resize — the ValueListenableBuilder fires
      // but the cached child is returned instead of rebuilding
      service.show('during resize');
      await tester.pump();

      // Resize must not freeze feedback content or its admission-time clock.
      expect(find.text('before'), findsNothing);
      expect(find.text('during resize'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('during resize'), findsNothing);
      resizing.dispose();
    });

    testWidgets('resumes rebuild after resize ends', (tester) async {
      final resizing = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsdOverlay(service: service, resizing: resizing),
          ),
        ),
      );

      service.show('first');
      await tester.pump();
      expect(find.text('first'), findsOneWidget);

      // Start resizing
      resizing.value = true;
      await tester.pump();

      // End resizing
      resizing.value = false;
      await tester.pump();

      // Show a new message after resize ends — should rebuild normally
      service.show('after');
      await tester.pump();

      expect(find.text('after'), findsOneWidget);

      // Clean up timers
      service.hide();
      await tester.pump(const Duration(seconds: 2));
      resizing.dispose();
    });

    // ── Build-phase publication guard ──

    testWidgets(
      'show during build defers to frame end without setState error',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // 先挂载订阅者: 同级 Builder 之后调用 show 时, overlay 已在监听。
                  // 同步发布会让 overlay 在构建期 setState — 同级元素不可标脏,
                  // 这正是守卫要拦下的 setState-during-build 崩溃路径。
                  OsdOverlay(service: service),
                  Builder(
                    builder: (context) {
                      service.show('from build');
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // 帧末冲刷到达后, 下一帧渲染出内容。
        await tester.pump();
        expect(find.text('from build'), findsOneWidget);
        // 走完 1200ms 生命期, 不留挂起计时器。
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });
}
