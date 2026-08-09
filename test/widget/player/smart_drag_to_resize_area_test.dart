import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/smart_drag_to_resize_area.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  testWidgets('enabled 切换时保持固定祖先拓扑和 child State identity', (tester) async {
    // GlobalKey 直接观测 Stateful child，避免用 build 次数间接推断 Element 是否复用。
    final probeKey = GlobalKey<_StateProbeState>();

    await tester.pumpWidget(_TestHost(enabled: true, probeKey: probeKey));
    final initialState = probeKey.currentState;

    expect(initialState, isNotNull);
    _expectStableTopology(tester, ignoring: false);

    // 窗口态应允许指针到达内容区。
    await tester.tap(find.byType(_StateProbe));
    expect(initialState?.pointerDownCount, 1);

    await tester.pumpWidget(_TestHost(enabled: false, probeKey: probeKey));

    expect(identical(probeKey.currentState, initialState), isTrue);
    _expectStableTopology(tester, ignoring: true);

    // 全屏态由常驻 IgnorePointer 阻断交互，但不卸载内容 State。
    await tester.tap(find.byType(_StateProbe), warnIfMissed: false);
    expect(initialState?.pointerDownCount, 1);

    await tester.pumpWidget(_TestHost(enabled: true, probeKey: probeKey));

    expect(identical(probeKey.currentState, initialState), isTrue);
    _expectStableTopology(tester, ignoring: false);

    // 回到窗口态后，同一个 State 应恢复接收指针事件。
    await tester.tap(find.byType(_StateProbe));
    expect(initialState?.pointerDownCount, 2);
  });
}

/// 验证开关只更新 [IgnorePointer.ignoring]，不会替换拖拽区域的祖先结构。
void _expectStableTopology(WidgetTester tester, {required bool ignoring}) {
  final ignorePointer = tester.widget<IgnorePointer>(
    find.byType(IgnorePointer),
  );
  final dragArea = tester.widget<DragToResizeArea>(
    find.descendant(
      of: find.byType(IgnorePointer),
      matching: find.byType(DragToResizeArea),
    ),
  );

  expect(ignorePointer.ignoring, ignoring);
  expect(dragArea.child, isA<_StateProbe>());
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.enabled, required this.probeKey});

  final bool enabled;
  final GlobalKey<_StateProbeState> probeKey;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SmartDragToResizeArea(
        enabled: enabled,
        child: _StateProbe(key: probeKey),
      ),
    );
  }
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key});

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  int pointerDownCount = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => pointerDownCount += 1,
      child: const SizedBox.expand(),
    );
  }
}
