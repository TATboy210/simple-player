import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/widgets/osd_overlay.dart';

void main() {
  tearDown(() {
    OsdService.I.hide();
  });

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
      OsdService.I.show('50%', progress: 0.5);

      expect(OsdService.I.visible.value, isTrue);
      expect(OsdService.I.message.value, isNotNull);
      expect(OsdService.I.message.value!.text, '50%');
      expect(OsdService.I.message.value!.progress, 0.5);
      OsdService.I.hide();
    });

    test('show() with icon', () {
      OsdService.I.show('Muted', icon: Icons.volume_off);

      expect(OsdService.I.message.value!.icon, Icons.volume_off);
      OsdService.I.hide();
    });

    test('hide() clears message and visible', () {
      OsdService.I.show('test');
      expect(OsdService.I.visible.value, isTrue);

      OsdService.I.hide();

      expect(OsdService.I.visible.value, isFalse);
      expect(OsdService.I.message.value, isNull);
    });
  });

  group('OsdOverlay widget', () {
    testWidgets('renders SizedBox.shrink when no message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OsdOverlay())),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders text when message is shown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OsdOverlay())),
      );

      OsdService.I.show('75%');
      await tester.pump();

      expect(find.text('75%'), findsOneWidget);

      // Let the hide timer fire to avoid pending timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders icon when message has icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OsdOverlay())),
      );

      OsdService.I.show('Muted', icon: Icons.volume_off);
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders progress bar when message has progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OsdOverlay())),
      );

      OsdService.I.show('50%', progress: 0.5);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides when message is cleared', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OsdOverlay())),
      );

      OsdService.I.show('test');
      await tester.pump();
      expect(find.text('test'), findsOneWidget);

      OsdService.I.hide();
      await tester.pump();

      expect(find.text('test'), findsNothing);
    });
  });
}
