import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';

void main() {
  testWidgets(
    'menu clamps edges and pairs hover press cancel and outside dismissal',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final context = tester.element(find.byType(Scaffold));
      final result = GlassMenu.show(
        context,
        position: const Offset(799, 599),
        items: const [
          GlassMenuItem(Icons.play_arrow, '播放 mixed label', value: 'play'),
          GlassMenuItem(
            Icons.delete,
            'Remove',
            value: 'remove',
            isDestructive: true,
          ),
        ],
      );
      await tester.pump();
      final label = find.text('播放 mixed label');
      final rect = tester.getRect(
        find.ancestor(of: label, matching: find.byType(Material)).first,
      );
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.top, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(792));
      // Estimated row bounds exclude the existing two-pixel decoration border.
      expect(rect.bottom, lessThanOrEqualTo(600));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(label));
      await tester.pump();
      final row = find
          .ancestor(of: label, matching: find.byType(AnimatedContainer))
          .first;
      expect(switch (tester.widget<AnimatedContainer>(row).decoration) {
        BoxDecoration(:final color) => color,
        _ => null,
      }, Colors.white.withValues(alpha: 0.06));
      await mouse.down(tester.getCenter(label));
      await tester.pump();
      expect(switch (tester.widget<AnimatedContainer>(row).decoration) {
        BoxDecoration(:final color) => color,
        _ => null,
      }, Colors.black.withValues(alpha: 0.12));
      await mouse.cancel();
      await tester.pump();
      expect(switch (tester.widget<AnimatedContainer>(row).decoration) {
        BoxDecoration(:final color) => color,
        _ => null,
      }, Colors.white.withValues(alpha: 0.06));
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(switch (tester.widget<AnimatedContainer>(row).decoration) {
        BoxDecoration(:final color) => color,
        _ => null,
      }, Colors.transparent);
      await mouse.removePointer();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(await result, isNull);
      expect(label, findsNothing);
      final chosen = GlassMenu.show(
        context,
        position: const Offset(-100, -100),
        items: const [GlassMenuItem(Icons.play_arrow, 'Play', value: 'play')],
      );
      await tester.pump();
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(await chosen, 'play');
    },
  );
}
