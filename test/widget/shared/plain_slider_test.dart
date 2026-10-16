import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/plain_slider.dart';
import 'package:simple_player_flutter/ui/shared/setting_slider_row.dart';

/// PlainSlider 契约 — 替换 Material Slider 的根因: 后者常驻值指示器
/// OverlayPortal, 其语义节点挂在 Overlay 根下, Windows 无障碍桥每次更新报
/// `Failed to update ui::AXTree` 并重建整树 (控制栏鼠标移动卡顿源).
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 200, child: child)),
    ),
  );

  testWidgets('volume slider and setting row contain no OverlayPortal', (
    tester,
  ) async {
    final volume = ValueNotifier(0.5);
    final setting = ValueNotifier(0.0);
    addTearDown(volume.dispose);
    addTearDown(setting.dispose);
    await tester.pumpWidget(
      host(
        Column(
          children: [
            VolumeSlider(volume: volume, onSetVolume: (_) {}),
            SettingSliderRow(label: 'x', notifier: setting),
          ],
        ),
      ),
    );
    expect(find.byType(OverlayPortal), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('pointer drag reports start/changed/end in Material order', (
    tester,
  ) async {
    final log = <String>[];
    var value = 0.5;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => PlainSlider(
            value: value,
            onChangeStart: (v) => log.add('start'),
            onChanged: (v) => setState(() => value = v),
            onChangeEnd: (v) => log.add('end:${v.toStringAsFixed(2)}'),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(PlainSlider));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(Offset(rect.right, rect.center.dy));
    await gesture.up();
    await tester.pump();
    expect(value, 1.0);
    expect(log, ['start', 'end:1.00']);
  });

  testWidgets('arrow keys step 5% via onChanged only when focused', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final changes = <double>[];
    var starts = 0;
    await tester.pumpWidget(
      host(
        PlainSlider(
          focusNode: node,
          value: 0.5,
          onChanged: changes.add,
          onChangeStart: (_) => starts++,
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    expect(changes, [closeTo(0.55, 1e-9), closeTo(0.45, 1e-9)]);
    expect(starts, 0, reason: '键盘路径不发 onChangeStart (Material 同语义)');
  });

  testWidgets('exposes slider semantics with increase/decrease actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(PlainSlider(value: 0.3, onChanged: (_) {})));
    expect(
      tester.getSemantics(find.byType(PlainSlider)),
      matchesSemantics(
        isSlider: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        value: '30%',
        increasedValue: '35%',
        decreasedValue: '25%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    handle.dispose();
  });
}
