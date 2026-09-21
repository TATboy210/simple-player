// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
/// GlassButton 光标解析实证测试 (v0.0.6.2) — 复现 MouseTracker 的
/// firstNonDeferred 解析, 验证 hover 命中路径上的光标注解序列.
///
/// 背景: 用户实测控制栏 GlassButton 系按钮 hover 为箭头, 而
/// SpeedButton (InkWell.mouseCursor: click) 与 VolumeSlider (原生
/// clickable) 为食指. 本测试读命中路径上全部 RenderMouseRegion 的
/// cursor 值, 实证 GlassButton 的 click 是否会被框架选中.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 模拟鼠标悬停并按 MouseTracker 规则解析光标:
  /// 命中路径 (child 先 add = 由深到浅) 中第一个非 defer 的 cursor 胜出
  /// (MouseCursor.defer 文档: "from front to back in hit-test order").
  MouseCursor resolveCursor(WidgetTester tester, Offset location) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      location,
      tester.view.viewId,
    );
    // 复现 MouseTracker firstNonDeferred: 命中路径 (深→浅) 第一个非 defer.
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) {
        return target.cursor;
      }
    }
    return SystemMouseCursors.basic; // 全 defer — 系统箭头兜底
  }

  group('GlassButton 光标解析实证 (v0.0.6.2)', () {
    testWidgets('iconOnly 按钮 hover — 命中路径应解析出 click', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.iconOnly(
                icon: Icons.play_arrow,
                onPressed: () {},
                tooltip: 'play',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final center = tester.getCenter(find.byIcon(Icons.play_arrow));
      await gesture.moveTo(center);
      await tester.pump();

      expect(resolveCursor(tester, center), SystemMouseCursors.click);
    });

    testWidgets('SpeedButton hover — InkWell.mouseCursor 应解析出 click', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SpeedButton(
                rate: ValueNotifier<double>(1.0),
                onSetRate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final center = tester.getCenter(find.byType(SpeedButton));
      await gesture.moveTo(center);
      await tester.pump();

      expect(resolveCursor(tester, center), SystemMouseCursors.click);
    });

    testWidgets('disabled 按钮 — 解析出 basic (箭头合理)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.iconOnly(
                icon: Icons.play_arrow,
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final center = tester.getCenter(find.byIcon(Icons.play_arrow));
      await gesture.moveTo(center);
      await tester.pump();

      expect(resolveCursor(tester, center), SystemMouseCursors.basic);
    });
  });
}
