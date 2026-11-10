import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/port/window_resize_edge.dart';
import 'package:simple_player_flutter/ui/window/resize_hot_zones.dart';

import '../../helpers/fake_window_service.dart';

void main() {
  late FakeWindowService windowService;

  setUp(() => windowService = FakeWindowService());
  tearDown(() => windowService.dispose());

  Future<void> pumpZones(WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 800,
            height: 600,
            child: ResizeHotZones(windowService: windowService),
          ),
        ),
      ),
    );
  }

  testWidgets('left edge press starts a left resize', (tester) async {
    await pumpZones(tester);

    await tester.tapAt(const Offset(3, 300));

    expect(windowService.startResizingCallCount, 1);
    expect(windowService.lastResizeEdge, WindowResizeEdge.left);
  });

  testWidgets('bottom edge press starts a bottom resize', (tester) async {
    await pumpZones(tester);

    await tester.tapAt(const Offset(400, 597));

    expect(windowService.lastResizeEdge, WindowResizeEdge.bottom);
  });

  testWidgets('corner press wins over the edge bands', (tester) async {
    await pumpZones(tester);

    // 右下角 2px 内 — 角块（后声明）优先于边带命中。
    await tester.tapAt(const Offset(799, 599));

    expect(windowService.lastResizeEdge, WindowResizeEdge.bottomRight);
  });

  testWidgets('window center is not a resize zone', (tester) async {
    await pumpZones(tester);

    await tester.tapAt(const Offset(400, 300));

    expect(windowService.startResizingCallCount, 0);
  });
}
