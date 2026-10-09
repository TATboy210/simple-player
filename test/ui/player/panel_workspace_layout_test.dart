import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_layout.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  test('854 minimum gives center and reserved playlist 280', () {
    final layout = PanelWorkspaceLayout.calculate(const Size(854, 480));
    expect(layout.center.width, 280);
    expect(layout.left.width, 234);
    // 单源对齐锁: 播放列表宽度与工作区右列预留宽出自同一常量,
    // 任一侧改动不再分叉 (W5 双源魔法数消除的结构保证)。
    expect(PlaylistPanel.panelWidth, Tokens.workspaceTaskMinWidth);
    // 数学钉死右列预留: 794 可分配宽 (854 − margin 18×2 − gap 12×2)
    // 减 left/center 二者恰余 280 — 与播放列表槽位精确对齐。
    expect(
      794 - layout.left.width - layout.center.width,
      Tokens.workspaceTaskMinWidth,
    );
  });

  test('right-third surplus transfers to center at wider sizes', () {
    for (final width in [1280.0, 1920.0]) {
      final layout = PanelWorkspaceLayout.calculate(Size(width, 720));
      final distributable = width - 36 - 24;
      expect(layout.left.width, closeTo(distributable / 3, 0.001));
      // center 吞掉右 1/3 盈余后恰余 280 给右列 (隐含, 不再直测矩形)。
      expect(layout.center.width, closeTo(distributable * 2 / 3 - 280, 0.001));
    }
  });

  test('narrow and short fallback has nonnegative bounded rectangles', () {
    for (final size in [Size.zero, const Size(20, 10), const Size(300, 100)]) {
      final layout = PanelWorkspaceLayout.calculate(size);
      for (final rect in [layout.left, layout.center]) {
        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    }
  });
}
