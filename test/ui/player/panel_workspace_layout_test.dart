import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_layout.dart';

void main() {
  test('854 minimum gives center and reserved playlist 280', () {
    final layout = PanelWorkspaceLayout.calculate(const Size(854, 480));
    expect(layout.center.width, 280);
    expect(layout.right.width, 280);
    expect(layout.left.width, 234);
    expect(layout.center.height, layout.right.height);
    expect(layout.center.right + 12, layout.right.left);
  });

  test('right-third surplus transfers to center at wider sizes', () {
    for (final width in [1280.0, 1920.0]) {
      final layout = PanelWorkspaceLayout.calculate(Size(width, 720));
      final distributable = width - 36 - 24;
      expect(layout.left.width, closeTo(distributable / 3, 0.001));
      expect(layout.center.width, closeTo(distributable * 2 / 3 - 280, 0.001));
      expect(layout.right.width, 280);
      expect(layout.right.right, width - 18);
    }
  });

  test('narrow and short fallback has nonnegative bounded rectangles', () {
    for (final size in [Size.zero, const Size(20, 10), const Size(300, 100)]) {
      final layout = PanelWorkspaceLayout.calculate(size);
      for (final rect in [layout.left, layout.center, layout.right]) {
        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    }
  });
}
