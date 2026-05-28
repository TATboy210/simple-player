import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_widgets.dart';

void main() {
  Widget buildSubject({
    required IconData icon,
    String? label,
    String? tooltip,
    bool isPrimary = false,
    bool enabled = true,
    VoidCallback? onPressed,
    void Function(TapUpDetails)? onSecondaryTapUp,
    double iconSize = 20.0,
    Color? color,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: label != null
              ? GlassButton(
                  icon: icon,
                  label: label,
                  tooltip: tooltip,
                  isPrimary: isPrimary,
                  enabled: enabled,
                  onPressed: onPressed ?? () {},
                  onSecondaryTapUp: onSecondaryTapUp,
                  iconSize: iconSize,
                  color: color,
                )
              : GlassButton.iconOnly(
                  icon: icon,
                  tooltip: tooltip,
                  isPrimary: isPrimary,
                  enabled: enabled,
                  onPressed: onPressed ?? () {},
                  onSecondaryTapUp: onSecondaryTapUp,
                  iconSize: iconSize,
                  color: color,
                ),
        ),
      ),
    );
  }

  group('GlassButton icon-only mode', () {
    testWidgets('renders Icon widget', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.play_arrow));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('does not render Text widget', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.play_arrow));
      await tester.pump();

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('tap fires onPressed callback', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        buildSubject(icon: Icons.play_arrow, onPressed: () => tapCount++),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(tapCount, 1);
    });

    testWidgets('disabled button does not fire onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          enabled: false,
          onPressed: () => tapCount++,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(tapCount, 0);
    });

    testWidgets('onSecondaryTapUp receives TapUpDetails', (tester) async {
      TapUpDetails? receivedDetails;
      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          onSecondaryTapUp: (d) => receivedDetails = d,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byIcon(Icons.play_arrow),
        buttons: kSecondaryButton,
      );
      expect(receivedDetails, isNotNull);
    });
  });

  group('GlassButton label mode', () {
    testWidgets('renders Icon and Text', (tester) async {
      await tester.pumpWidget(
        buildSubject(icon: Icons.folder_open, label: 'Open File'),
      );
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);
    });

    testWidgets('tap fires onPressed callback', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          onPressed: () => tapCount++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open File'));
      expect(tapCount, 1);
    });

    testWidgets('disabled button does not fire onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          enabled: false,
          onPressed: () => tapCount++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open File'));
      expect(tapCount, 0);
    });
  });
}
