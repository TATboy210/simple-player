import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('renders title text correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Test Title'),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'With Icon',
              icon: Icons.language,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Title',
              description: 'Description text',
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description text'), findsOneWidget);
    });

    testWidgets('uses Tokens.textSecondary for title color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Color Test'),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Color Test'));
      final style = text.style;
      expect(style?.color, Tokens.textSecondary);
    });

    testWidgets('uses Tokens.fontCaption for title font size',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Font Test'),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Font Test'));
      final style = text.style;
      expect(style?.fontSize, Tokens.fontCaption);
    });
  });
}
