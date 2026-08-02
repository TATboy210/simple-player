import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    FocusNode? focusNode,
    String? semanticsLabel,
    bool? semanticsToggled,
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
                  focusNode: focusNode,
                  semanticsLabel: semanticsLabel,
                  semanticsToggled: semanticsToggled,
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
                  focusNode: focusNode,
                  semanticsLabel: semanticsLabel,
                  semanticsToggled: semanticsToggled,
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

  group('GlassButton keyboard and semantics contract', () {
    testWidgets('Space activates the focused button once', (tester) async {
      var activationCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          focusNode: focusNode,
          onPressed: () => activationCount++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(activationCount, 1);
    });

    testWidgets('Enter activates the focused button once', (tester) async {
      var activationCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          focusNode: focusNode,
          onPressed: () => activationCount++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(activationCount, 1);
    });

    testWidgets('activator keys do not bubble past the focused button', (
      tester,
    ) async {
      var activationCount = 0;
      var ancestorKeyDownCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.space ||
                        event.logicalKey == LogicalKeyboardKey.enter)) {
                  ancestorKeyDownCount++;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Center(
                child: GlassButton.iconOnly(
                  icon: Icons.play_arrow,
                  focusNode: focusNode,
                  onPressed: () => activationCount++,
                ),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(activationCount, 2);
      expect(ancestorKeyDownCount, 0);
    });

    testWidgets('exposes its explicit semantic label and toggled state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.pause,
          semanticsLabel: 'Pause',
          semanticsToggled: true,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Pause')),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('focus feedback preserves the icon hit-test geometry', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(icon: Icons.play_arrow, focusNode: focusNode),
      );
      final rectBeforeFocus = tester.getRect(find.byIcon(Icons.play_arrow));

      focusNode.requestFocus();
      await tester.pump();

      expect(tester.getRect(find.byIcon(Icons.play_arrow)), rectBeforeFocus);
    });
  });

  group('GlassButton focus traversal contract', () {
    testWidgets('each visual button occupies one Tab stop', (tester) async {
      var firstActivationCount = 0;
      var secondActivationCount = 0;
      final scopeNode = FocusScopeNode();
      addTearDown(scopeNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusScope(
              node: scopeNode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton.iconOnly(
                    icon: Icons.skip_previous,
                    onPressed: () => firstActivationCount++,
                  ),
                  GlassButton.iconOnly(
                    icon: Icons.replay_10,
                    onPressed: () => secondActivationCount++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // FocusableActionDetector is the only keyboard-focus owner per button.
      scopeNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(firstActivationCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(secondActivationCount, 1);
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
