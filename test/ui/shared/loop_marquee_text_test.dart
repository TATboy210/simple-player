import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/loop_marquee_text.dart';

void main() {
  // 200px 容器 + fontSize 14 → ~14px/字符, 30 字符 ≈ 420px 必然超宽
  const longText = 'very-long-summary-text-for-loop-marquee-scrolling-123456';
  const shortText = 'short.mp4';

  Widget buildSubject(
    String text, {
    TextStyle? style,
    bool disableAnimations = false,
    double width = 200,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: SizedBox(
              width: width,
              height: 24,
              child: LoopMarqueeText(
                text: text,
                style: style ?? const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 返回当前平移量 dx（仅认 Transform.translate 构造 — origin/alignment 为
  /// null 是其特征）；无平移 widget 时返回 null。
  double? findTranslateDx(WidgetTester tester) {
    for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
      if (t.origin == null && t.alignment == null) {
        return t.transform.getTranslation().x;
      }
    }
    return null;
  }

  testWidgets('短文本静止渲染，不产生平移', (tester) async {
    await tester.pumpWidget(buildSubject(shortText));
    await tester.pump(const Duration(milliseconds: 100));

    expect(findTranslateDx(tester), isNull);
    expect(find.text(shortText), findsOneWidget);
  });

  testWidgets('超长文本单向循环滚动，平移量随时间负向递增', (tester) async {
    await tester.pumpWidget(buildSubject(longText));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final firstDx = findTranslateDx(tester);
    expect(firstDx, isNotNull);
    expect(firstDx, isNegative); // 向左滚动展示尾部内容

    await tester.pump(const Duration(seconds: 1));
    final secondDx = findTranslateDx(tester);
    expect(secondDx, isNotNull);
    expect(secondDx, lessThan(firstDx!)); // 持续负向递增
  });

  testWidgets('滚动全程无 RenderFlex overflow（OverflowBox 回归锁）', (tester) async {
    final exceptions = <FlutterErrorDetails>[];
    await tester.pumpWidget(buildSubject(longText));
    // pump 多帧覆盖滚动全程 — Row 超宽约束若未经 OverflowBox 放开，
    // debug paint 断言会在此抛出。
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(exceptions, isEmpty);
    expect(findTranslateDx(tester), isNotNull);
  });

  testWidgets('系统减少动画时超长文本静止并 ellipsis 截断', (tester) async {
    await tester.pumpWidget(buildSubject(longText, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(findTranslateDx(tester), isNull);
    final text = tester.widget<Text>(find.byType(Text).first);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('容器加宽后由滚动切换为静止（响应式联动）', (tester) async {
    await tester.pumpWidget(buildSubject(longText, width: 200));
    await tester.pump();
    expect(findTranslateDx(tester), isNotNull);

    // 宽度放大到足以容纳全文 → 停止滚动，恢复静止 Text。
    await tester.pumpWidget(buildSubject(longText, width: 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(findTranslateDx(tester), isNull);
  });
}
