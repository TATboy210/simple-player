import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/marquee_text.dart';

void main() {
  // 200px 容器 + fontSize 14 → ~14px/字符, 30 字符 ≈ 420px 必然超宽
  const longText = 'very-long-video-file-name-for-marquee-scrolling-123456.mp4';
  const shortText = 'short.mp4';

  Widget buildSubject(
    String text, {
    TextStyle? style,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: SizedBox(
              width: 200,
              height: 24,
              child: MarqueeText(
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

  testWidgets('超长文本往返滚动，平移量随时间变化', (tester) async {
    await tester.pumpWidget(buildSubject(longText));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final firstDx = findTranslateDx(tester);
    expect(firstDx, isNotNull);
    expect(firstDx, isNegative); // 向左滚动展示尾部内容

    await tester.pump(const Duration(seconds: 1));
    final secondDx = findTranslateDx(tester);

    expect(secondDx, isNot(equals(firstDx)));
  });

  testWidgets('系统减少动画时超长文本静止并 ellipsis 截断', (tester) async {
    await tester.pumpWidget(buildSubject(longText, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(findTranslateDx(tester), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('文本更新长→短后停止滚动恢复静止', (tester) async {
    await tester.pumpWidget(buildSubject(longText));
    await tester.pump();
    expect(findTranslateDx(tester), isNotNull);

    await tester.pumpWidget(buildSubject(shortText));
    await tester.pump(const Duration(milliseconds: 100));

    expect(findTranslateDx(tester), isNull);
    expect(find.text(shortText), findsOneWidget);
  });
}
