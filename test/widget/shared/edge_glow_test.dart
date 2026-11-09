import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/edge_glow.dart';

void main() {
  group('EdgeGlow', () {
    testWidgets('renders child with the 5-layer glow shadow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EdgeGlow(child: SizedBox(width: 100, height: 50)),
          ),
        ),
      );

      expect(find.byType(EdgeGlow), findsOneWidget);
      // 发光层恒为 5 层 box-shadow（含 blur 20/50 两层大半径）。
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EdgeGlow),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.boxShadow, hasLength(5));
    });
  });
}
