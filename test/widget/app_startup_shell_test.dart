import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/locale_service.dart';
import 'package:simple_player_flutter/kernel/services/theme_service.dart';
import 'package:simple_player_flutter/kernel/startup/startup_coordinator.dart';

import '../helpers/fake_window_service.dart';

void main() {
  setUpAll(KernelLoggerImpl.init);

  setUp(() {
    LocaleService.I.locale.value = const Locale('zh');
    ThemeService.I.themeIndex.value = 0;
  });

  testWidgets(
    'keeps the app shell mounted across settings, locale, and theme changes',
    (tester) async {
      final settingsGate = Completer<void>();
      final coordinator = StartupCoordinator();
      final windowService = FakeWindowService();
      final lifecycle = _ReadyLifecycle();

      try {
        await tester.pumpWidget(
          App(
            coordinator: coordinator,
            windowService: windowService,
            initializeSettings: () => settingsGate.future,
            readyHomeBuilder: (_) => _ReadyProbe(lifecycle: lifecycle),
          ),
        );

        expect(find.byKey(_readyProbeKey), findsNothing);

        final materialAppBefore = tester.element(find.byType(MaterialApp));
        final navigatorBefore = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        final overlayBefore = tester.state<OverlayState>(find.byType(Overlay));

        settingsGate.complete();
        // Future completion resumes _init in a microtask, then setState schedules
        // the route-local startup gate update on the following frame.
        await tester.pump();
        await tester.pump();

        expect(find.byKey(_readyProbeKey), findsOneWidget);
        expect(lifecycle.mounts, 1);
        expect(lifecycle.disposals, 0);
        expect(
          tester.element(find.byType(MaterialApp)),
          same(materialAppBefore),
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigatorBefore),
        );
        expect(
          tester.state<OverlayState>(find.byType(Overlay)),
          same(overlayBefore),
        );

        final readyElementBefore = tester.element(find.byKey(_readyProbeKey));

        // Direct notifier updates isolate shell rebuilding from persistence I/O.
        LocaleService.I.locale.value = const Locale('en');
        ThemeService.I.themeIndex.value = 1;
        await tester.pump();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.locale, const Locale('en'));
        expect(materialApp.theme?.colorScheme.primary, ThemeService.accents[1]);
        expect(
          tester.element(find.byType(MaterialApp)),
          same(materialAppBefore),
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigatorBefore),
        );
        expect(
          tester.state<OverlayState>(find.byType(Overlay)),
          same(overlayBefore),
        );
        expect(
          tester.element(find.byKey(_readyProbeKey)),
          same(readyElementBefore),
        );
        expect(lifecycle.mounts, 1);
        expect(lifecycle.disposals, 0);
      } finally {
        // App owns WindowBridge disposal; unmount it before disposing the
        // coordinator that still drives the startup splash builder.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        coordinator.dispose();
      }
    },
  );
}

const _readyProbeKey = ValueKey<String>('ready-probe');

class _ReadyLifecycle {
  int mounts = 0;
  int disposals = 0;
}

class _ReadyProbe extends StatefulWidget {
  const _ReadyProbe({required this.lifecycle}) : super(key: _readyProbeKey);

  final _ReadyLifecycle lifecycle;

  @override
  State<_ReadyProbe> createState() => _ReadyProbeState();
}

class _ReadyProbeState extends State<_ReadyProbe> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.mounts++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
