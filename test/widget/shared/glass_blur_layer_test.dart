// ignore_for_file: avoid-unnecessary-type-assertions
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_blur_layer.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

/// GlassBlurLayer 统一玻璃门控层契约 (v0.0.8.2) —
/// 门控翻转只换 BackdropFilter.enabled 布尔, 子树恒挂载 (渲染结构恒定),
/// filter 走 GlassTier 缓存单例, 数量恒为 1 (findsOneWidget 契约).
void main() {
  Future<void> pumpLayer(
    WidgetTester tester, {
    Animation<double>? opacity,
    ValueListenable<bool>? suspend,
    bool enabled = true,
    ImageFilter? filter,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassBlurLayer(
            opacity: opacity,
            suspend: suspend,
            enabled: enabled,
            filter: filter,
            child: const Text('glass-content'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BackdropFilter backdrop(WidgetTester tester) =>
      tester.widget<BackdropFilter>(find.byType(BackdropFilter));

  testWidgets('无门控源 — 恒启用且 BackdropFilter 数量恒 1', (tester) async {
    await pumpLayer(tester);

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(backdrop(tester).enabled, isTrue);
    expect(find.text('glass-content'), findsOneWidget);
  });

  testWidgets('opacity<0.01 停用 — 模糊关但子树仍挂载', (tester) async {
    final controller = AnimationController(vsync: tester, value: 0.0);
    addTearDown(controller.dispose);
    await pumpLayer(tester, opacity: controller);

    expect(backdrop(tester).enabled, isFalse, reason: '淡出尾段停用采样');
    expect(find.text('glass-content'), findsOneWidget, reason: '子树恒挂载');

    controller.value = 1.0;
    await tester.pump();
    expect(backdrop(tester).enabled, isTrue);
  });

  testWidgets('suspend 挂起/恢复 — element identity 保持 (拓扑恒定)', (tester) async {
    final suspend = ValueNotifier<bool>(false);
    addTearDown(suspend.dispose);
    await pumpLayer(tester, suspend: suspend);
    expect(backdrop(tester).enabled, isTrue);

    final elementBefore = tester.element(find.text('glass-content'));

    suspend.value = true;
    await tester.pump();
    expect(backdrop(tester).enabled, isFalse, reason: 'seek 拖动期间挂起');
    expect(find.text('glass-content'), findsOneWidget);

    suspend.value = false;
    await tester.pump();
    expect(backdrop(tester).enabled, isTrue, reason: '松手一帧恢复');

    expect(
      tester.element(find.text('glass-content')),
      same(elementBefore),
      reason: '门控翻转不得重建子树拓扑',
    );
  });

  testWidgets('enabled=false 静态开关 — 恒停用 (低配降级通路)', (tester) async {
    final controller = AnimationController(vsync: tester, value: 1.0);
    addTearDown(controller.dispose);
    await pumpLayer(tester, opacity: controller, enabled: false);

    expect(backdrop(tester).enabled, isFalse);
  });

  testWidgets('filter 缺省 normal 档缓存单例透传', (tester) async {
    await pumpLayer(tester);

    expect(
      identical(backdrop(tester).filter, GlassTier.normal.blurFilter),
      isTrue,
      reason: '零分配契约 — 与控制栏同一 filter 实例',
    );
  });

  testWidgets('自定义 filter 透传 (thin 档)', (tester) async {
    await pumpLayer(tester, filter: GlassTier.thin.blurFilter);

    expect(
      identical(backdrop(tester).filter, GlassTier.thin.blurFilter),
      isTrue,
    );
  });
}
