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
    bool allowNullOnPressed = false,
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
                  onPressed: allowNullOnPressed
                      ? onPressed
                      : (onPressed ?? () {}),
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
                  onPressed: allowNullOnPressed
                      ? onPressed
                      : (onPressed ?? () {}),
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

      // Disabled buttons deliberately ignore hit testing; assert the implementation
      // contract before suppressing the expected test-framework miss warning.
      final icon = find.byIcon(Icons.play_arrow);
      final disabledHitBlocker = find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      );
      expect(
        find.descendant(of: disabledHitBlocker, matching: icon),
        findsOneWidget,
      );
      final inkWell = find.ancestor(of: icon, matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(inkWell).onTap, isNull);
      await tester.tap(icon, warnIfMissed: false);
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

    testWidgets('uses the latest onPressed callback after rebuild', (
      tester,
    ) async {
      var firstActivationCount = 0;
      var secondActivationCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          focusNode: focusNode,
          onPressed: () => firstActivationCount++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          focusNode: focusNode,
          onPressed: () => secondActivationCount++,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(firstActivationCount, 1);
      expect(secondActivationCount, 1);
    });

    testWidgets('enabled to disabled rebuild ignores keyboard activation', (
      tester,
    ) async {
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

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          enabled: false,
          focusNode: focusNode,
          onPressed: () => activationCount++,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(activationCount, 1);
    });

    testWidgets('null onPressed exposes a disabled semantic button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.play_arrow,
          allowNullOnPressed: true,
          semanticsLabel: 'Unavailable',
          onPressed: null,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Unavailable')),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
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

      // Disabled buttons intentionally reject pointer hit tests.
      await tester.tap(find.text('Open File'), warnIfMissed: false);
      expect(tapCount, 0);
    });

    testWidgets('uses the latest onPressed callback after rebuild', (
      tester,
    ) async {
      var firstActivationCount = 0;
      var secondActivationCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          focusNode: focusNode,
          onPressed: () => firstActivationCount++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          focusNode: focusNode,
          onPressed: () => secondActivationCount++,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(firstActivationCount, 1);
      expect(secondActivationCount, 1);
    });

    testWidgets('disabled rebuild blocks tap and keyboard activation', (
      tester,
    ) async {
      var activationCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          focusNode: focusNode,
          onPressed: () => activationCount++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      await tester.pumpWidget(
        buildSubject(
          icon: Icons.folder_open,
          label: 'Open File',
          enabled: false,
          focusNode: focusNode,
          onPressed: () => activationCount++,
        ),
      );
      await tester.pump();
      // Disabled buttons intentionally reject pointer hit tests.
      await tester.tap(find.text('Open File'), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(activationCount, 1);
    });

    testWidgets('null onPressed rebuild exposes disabled semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      try {
        await tester.pumpWidget(
          buildSubject(
            icon: Icons.folder_open,
            label: 'Open File',
            focusNode: focusNode,
            semanticsLabel: 'Open file action',
            onPressed: () {},
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        await tester.pumpWidget(
          buildSubject(
            icon: Icons.folder_open,
            label: 'Open File',
            allowNullOnPressed: true,
            focusNode: focusNode,
            semanticsLabel: 'Open file action',
            onPressed: null,
          ),
        );
        await tester.pump();

        expect(
          tester.getSemantics(find.bySemanticsLabel('Open file action')),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });
  });
}
