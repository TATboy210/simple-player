import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_banner.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('ErrorBanner', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    Widget buildSubject({
      VoidCallback? onOpenFile,
      VoidCallback? onRetry,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ErrorBanner(
            engine: engine,
            onOpenFile: onOpenFile,
            onRetry: onRetry,
          ),
        ),
      );
    }

    testWidgets('shows nothing when state is not error', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('shows nothing when errorMessage is null', (tester) async {
      engine.state.value = MediaState.error;
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays error message when in error state', (tester) async {
      engine.simulateError('File not found');
      await tester.pumpWidget(buildSubject());

      expect(find.text('File not found'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows action button for file error', (tester) async {
      var opened = false;
      engine.errorType = MediaErrorType.file;
      engine.simulateError('Cannot open');
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, isTrue);
    });

    testWidgets('shows retry button for playback error', (tester) async {
      var retried = false;
      engine.errorType = MediaErrorType.playback;
      engine.simulateError('Playback failed');
      await tester.pumpWidget(buildSubject(onRetry: () => retried = true));

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(retried, isTrue);
    });

    testWidgets('hides button when no callback provided', (tester) async {
      engine.errorType = MediaErrorType.unknown;
      engine.simulateError('Unknown error');
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows codec error with selectOtherFile action', (tester) async {
      var opened = false;
      engine.errorType = MediaErrorType.codec;
      engine.simulateError('Unsupported codec');
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      expect(find.text('Unsupported codec'), findsOneWidget);
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, isTrue);
    });
  });
}
