import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';
import 'package:simple_player_flutter/ui/player/controls_cursor_region.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

const _device = 1;

void main() {
  test('pointerInsideControlBar: 仅控制栏本体矩形内为真', () {
    const area = Size(1000, 600);
    final insideY =
        area.height -
        Tokens.controlBarMarginBottom -
        Tokens.controlBarHeight / 2;

    expect(pointerInsideControlBar(area, Offset(500, insideY)), isTrue);
    expect(pointerInsideControlBar(area, const Offset(500, 10)), isFalse);
    expect(
      pointerInsideControlBar(
        area,
        Offset(Tokens.controlBarMarginH - 1, insideY),
      ),
      isFalse,
    );
  });

  testWidgets('cursorHidden 翻转只切换光标，指针悬停控制栏区外不唤醒', (tester) async {
    final playing = ValueNotifier<bool>(false);
    final hidden = ValueNotifier<bool>(false);
    final autoHide = AutoHideController(
      vsync: tester,
      isPlaying: playing,
      isFullscreen: false,
    )..init();
    autoHide.pinned = true; // 取消 init 的隐藏计时，避免残留 Timer
    addTearDown(() {
      autoHide.dispose();
      playing.dispose();
      hidden.dispose();
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ControlsCursorRegion(autoHide: autoHide, cursorHidden: hidden),
      ),
    );
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _device,
    );
    await mouse.addPointer(location: const Offset(100, 20));
    await tester.pump();
    final tracker = RendererBinding.instance.mouseTracker;

    expect(
      tracker.debugDeviceActiveCursor(_device),
      isNot(SystemMouseCursors.none),
    );

    hidden.value = true;
    await tester.pump();
    await mouse.moveTo(const Offset(120, 30));
    expect(tracker.debugDeviceActiveCursor(_device), SystemMouseCursors.none);

    hidden.value = false;
    await tester.pump();
    await mouse.moveTo(const Offset(130, 30));
    expect(
      tracker.debugDeviceActiveCursor(_device),
      isNot(SystemMouseCursors.none),
    );
    await mouse.removePointer();
  });
}
