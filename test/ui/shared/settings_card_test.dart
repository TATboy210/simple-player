import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/focusable_setting_row.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('SettingRow three-state contract', () {
    testWidgets('is transparent and borderless before hover or focus', (
      tester,
    ) async {
      // Arrange & Act
      await _pumpSettingRow(tester);

      // Assert
      final decoration = _rowDecoration(tester);
      expect(decoration.color, isNull);
      final border = decoration.border! as Border;
      expect(border.top.color, Colors.transparent);
      expect(border.top.width, 1);
    });

    testWidgets(
      'uses hover fill and focused one-pixel border without height shift',
      (tester) async {
        // Arrange
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await _pumpSettingRow(tester, focusNode: focusNode);
        final beforeFocusHeight = tester
            .getSize(find.byType(SettingRow))
            .height;

        // Act & Assert — hover is owned by the InkWell interaction surface.
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.hoverColor, Tokens.bgHover);

        // Act
        focusNode.requestFocus();
        await tester.pump();

        // Assert
        final decoration = _rowDecoration(tester);
        final border = decoration.border! as Border;
        expect(border.top.color, Tokens.controlBarBorderWhite);
        expect(border.top.width, 1);
        expect(
          tester.getSize(find.byType(SettingRow)).height,
          beforeFocusHeight,
        );
        expect(beforeFocusHeight, 40);
      },
    );

    testWidgets('delivers focus state to the active value builder', (
      tester,
    ) async {
      // Arrange
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableSettingRow(
              focusNode: focusNode,
              focusedBuilder: (context, focused) => Text(
                'Active value',
                style: TextStyle(
                  color: focused ? Tokens.accent : Tokens.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      focusNode.requestFocus();
      await tester.pump();

      // Assert
      final text = tester.widget<Text>(find.text('Active value'));
      expect(text.style?.color, Tokens.accent);
    });

    testWidgets('uses a non-focusable InkWell for ripple tap feedback', (
      tester,
    ) async {
      // Arrange
      var tapCount = 0;
      await _pumpSettingRow(tester, onTap: () => tapCount += 1);

      // Act
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Assert
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(find.byType(Material), findsWidgets);
      expect(inkWell.canRequestFocus, isFalse);
      expect(inkWell.autofocus, isFalse);
      expect(inkWell.splashColor, Tokens.accentLight);
      expect(tapCount, 1);
      expect(
        find.descendant(
          of: find.byType(SettingRow),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'uses the locked 40-pixel density and spXs horizontal padding',
      (tester) async {
        // Arrange & Act
        await _pumpSettingRow(tester);

        // Assert
        expect(tester.getSize(find.byType(SettingRow)).height, 40);
        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(SettingRow),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Padding &&
                  widget.padding ==
                      const EdgeInsets.symmetric(horizontal: Tokens.spXs),
            ),
          ),
        );
        expect(
          padding.padding,
          const EdgeInsets.symmetric(horizontal: Tokens.spXs),
        );
      },
    );
  });

  group('embedded setting controls', () {
    testWidgets('SettingSwitchRow toggles its notifier', (tester) async {
      // Arrange
      final notifier = ValueNotifier(false);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingSwitchRow(title: 'Deinterlace', notifier: notifier),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Assert
      expect(notifier.value, isTrue);
    });

    testWidgets('SettingSpinRow invokes callback from its right arrow', (
      tester,
    ) async {
      // Arrange
      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingSpinRow(
              title: 'Language',
              options: const ['zh', 'en'],
              currentIndex: 0,
              onChanged: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // Assert
      expect(selectedIndex, 1);
    });
  });
}

/// Pumps an interactive row inside a single focus owner for state assertions.
Future<void> _pumpSettingRow(
  WidgetTester tester, {
  FocusNode? focusNode,
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingRow(
          focusNode: focusNode,
          title: 'Playback speed',
          control: const Text('1.0x'),
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

/// Reads the focused wrapper's immediate decoration contract.
BoxDecoration _rowDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(FocusableSettingRow),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}
