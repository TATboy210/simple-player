import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/input_mode_detector.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/option_list_navigation_overlay.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/pending_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/general_tab.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  setUp(InputModeDetector.resetInstance);

  testWidgets('uses no BackdropFilter in its overlay subtree', (tester) async {
    await tester.pumpWidget(_wrapOverlay());

    final overlay = find.byType(OptionListNavigationOverlay);
    final filters = find.descendant(
      of: overlay,
      matching: find.byType(BackdropFilter),
    );

    expect(filters, findsNothing);
  });

  testWidgets('glows the top indicator for an upward arrow', (tester) async {
    await tester.pumpWidget(_wrapOverlay());

    InputModeDetector.instance.arrowGlow.value = ArrowDirection.up;
    await tester.pump();

    expect(
      _indicatorIcon(tester, OptionListNavigationOverlay.topIndicatorKey).color,
      Tokens.accentBlue,
    );
    expect(
      _indicatorIcon(
        tester,
        OptionListNavigationOverlay.bottomIndicatorKey,
      ).color,
      Tokens.textSecondary,
    );
  });

  testWidgets('glows the bottom indicator for a downward arrow', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapOverlay());

    InputModeDetector.instance.arrowGlow.value = ArrowDirection.down;
    await tester.pump();

    expect(
      _indicatorIcon(tester, OptionListNavigationOverlay.topIndicatorKey).color,
      Tokens.textSecondary,
    );
    expect(
      _indicatorIcon(
        tester,
        OptionListNavigationOverlay.bottomIndicatorKey,
      ).color,
      Tokens.accentBlue,
    );
  });

  testWidgets('shows neither indicator in the glow state when glow is null', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapOverlay());

    InputModeDetector.instance.arrowGlow.value = null;
    await tester.pump();

    expect(
      _indicatorIcon(tester, OptionListNavigationOverlay.topIndicatorKey).color,
      Tokens.textSecondary,
    );
    expect(
      _indicatorIcon(
        tester,
        OptionListNavigationOverlay.bottomIndicatorKey,
      ).color,
      Tokens.textSecondary,
    );
  });

  testWidgets(
    'paints both indicator containers with the glass background token',
    (tester) async {
      await tester.pumpWidget(_wrapOverlay());

      expect(
        _indicatorContainer(
          tester,
          OptionListNavigationOverlay.topIndicatorKey,
        ).color,
        Tokens.bgGlass,
      );
      expect(
        _indicatorContainer(
          tester,
          OptionListNavigationOverlay.bottomIndicatorKey,
        ).color,
        Tokens.bgGlass,
      );
    },
  );

  testWidgets(
    'GeneralTab passes its scroll view through the overlay child contract',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GeneralTab(pending: PendingSettingsState())),
        ),
      );

      final overlay = tester.widget<OptionListNavigationOverlay>(
        find.byType(OptionListNavigationOverlay),
      );

      expect(overlay.child, isA<SingleChildScrollView>());
    },
  );
}

Widget _wrapOverlay() => const MaterialApp(
  home: Scaffold(
    body: OptionListNavigationOverlay(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: Tokens.spXl),
            SizedBox(height: Tokens.spXl),
          ],
        ),
      ),
    ),
  ),
);

Icon _indicatorIcon(WidgetTester tester, Key indicatorKey) =>
    tester.widget<Icon>(
      find.descendant(
        of: find.byKey(indicatorKey),
        matching: find.byType(Icon),
      ),
    );

Container _indicatorContainer(WidgetTester tester, Key indicatorKey) =>
    tester.widget<Container>(
      find.descendant(
        of: find.byKey(indicatorKey),
        matching: find.byType(Container),
      ),
    );
