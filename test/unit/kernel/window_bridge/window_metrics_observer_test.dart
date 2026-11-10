import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_metrics_observer.dart';

/// WindowMetricsObserver 单测 — 只响应"尺寸真实变化"，同值抖动必须被过滤。
/// 尺寸源注入，不依赖 test binding 的 surface/view 联动细节。
void main() {
  test('dedupes same-size notifications and fires on real changes', () {
    var calls = 0;
    var fakeSize = const Size(1280, 720);
    final observer = WindowMetricsObserver(
      onGeometryChanged: () => calls++,
      currentSize: () => fakeSize,
    );

    observer.didChangeMetrics(); // 与基线同尺寸 → 过滤
    expect(calls, 0);

    fakeSize = const Size(900, 600);
    observer.didChangeMetrics();
    expect(calls, 1);

    observer.didChangeMetrics(); // 同尺寸重复通知（DPI 抖动类）→ 不再触发
    expect(calls, 1);

    fakeSize = const Size(1100, 700);
    observer.didChangeMetrics();
    expect(calls, 2);
  });

  testWidgets('is reachable as a real WidgetsBindingObserver', (tester) async {
    // 只验证接线面：注册/注销不抛，binding 会把它当观察者对待。
    var calls = 0;
    final observer = WindowMetricsObserver(
      onGeometryChanged: () => calls++,
      currentSize: () => const Size(1, 1),
    );
    WidgetsBinding.instance.addObserver(observer);
    addTearDown(() => WidgetsBinding.instance.removeObserver(observer));

    WidgetsBinding.instance.handleMetricsChanged();
    expect(calls, 0); // 注入尺寸恒定 → 观察者自身吞掉，接线本身不炸即通过
  });
}
