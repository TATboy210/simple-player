import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_chip.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

import 'golden_comparator.dart';

void main() {
  setUp(() => enableTolerantGoldens());

  group('GlassContainer golden', () {
    testWidgets('thin tier', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassContainer(
            tier: GlassTier.thin,
            blurEnabled: false,
            child: const Text('Thin'),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassContainer),
        matchesGoldenFile('goldens/glass_container_thin.png'),
      );
    });

    testWidgets('normal tier', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassContainer(
            tier: GlassTier.normal,
            blurEnabled: false,
            child: const Text('Normal'),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassContainer),
        matchesGoldenFile('goldens/glass_container_normal.png'),
      );
    });

    testWidgets('thick tier', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassContainer(
            tier: GlassTier.thick,
            blurEnabled: false,
            child: const Text('Thick'),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassContainer),
        matchesGoldenFile('goldens/glass_container_thick.png'),
      );
    });
  });

  group('GlassButton golden', () {
    testWidgets('label mode', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassButton(
            icon: Icons.play_arrow,
            label: 'Play',
            onPressed: () {},
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_label.png'),
      );
    });

    testWidgets('icon-only mode', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassButton.iconOnly(
            icon: Icons.pause,
            onPressed: () {},
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_icon_only.png'),
      );
    });
  });

  group('GlassChip golden', () {
    testWidgets('selected', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassChip(
            label: '1.0x',
            selected: true,
            onTap: () {},
          ),
        ),
      );
      await expectLater(
        find.byType(GlassChip),
        matchesGoldenFile('goldens/glass_chip_selected.png'),
      );
    });

    testWidgets('unselected', (tester) async {
      await tester.pumpWidget(
        wrapForGolden(
          GlassChip(
            label: '1.5x',
            selected: false,
            onTap: () {},
          ),
        ),
      );
      await expectLater(
        find.byType(GlassChip),
        matchesGoldenFile('goldens/glass_chip_unselected.png'),
      );
    });
  });
}
