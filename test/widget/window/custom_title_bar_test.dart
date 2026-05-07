import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/platform_service.dart';
import 'package:simple_player_flutter/kernel/ui/window/custom_title_bar.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import '../../helpers/fake_platform_service.dart';

void main() {
  late FakePlatformService fake;

  setUp(() {
    fake = FakePlatformService();
    PlatformService.init(fake);
  });

  tearDown(() {
    PlatformService.reset();
  });

  Widget buildSubject({ValueNotifier<String>? fileName}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomTitleBar(fileName: fileName ?? ValueNotifier('')),
      ),
    );
  }

  group('文件名显示', () {
    testWidgets('fileName 为空时显示 "Simple Player"', (tester) async {
      await tester.pumpWidget(buildSubject(fileName: ValueNotifier('')));
      await tester.pump();
      expect(find.text('Simple Player'), findsOneWidget);
    });

    testWidgets('fileName 有值时显示 "{name} — Simple Player"', (tester) async {
      final notifier = ValueNotifier('video.mp4');
      await tester.pumpWidget(buildSubject(fileName: notifier));
      await tester.pump();
      expect(find.text('video.mp4 — Simple Player'), findsOneWidget);
    });
  });

  group('Pin 按钮状态反射 (WC-01, WC-05)', () {
    testWidgets('pin 按钮存在且显示 push_pin 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('isAlwaysOnTop 为 true 时 pin 图标为 accent 色', (tester) async {
      await tester.pumpWidget(buildSubject());
      fake.isAlwaysOnTop.value = true;
      await tester.pump();
      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, const Color(0xFF6C5CE7)); // Tokens.accent
    });

    testWidgets('isAlwaysOnTop 为 false 时 pin 图标为 textSecondary 色', (tester) async {
      await tester.pumpWidget(buildSubject());
      fake.isAlwaysOnTop.value = false;
      await tester.pump();
      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, const Color(0xFF9999AA)); // Tokens.textSecondary
    });
  });

  group('Maximize 按钮状态反射 (WC-03, WC-05)', () {
    testWidgets('未最大化时显示 crop_square 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
    });

    testWidgets('最大化后显示 filter_none 图标', (tester) async {
      await tester.pumpWidget(buildSubject());
      fake.isMaximized.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
    });
  });

  group('窗口控制按钮存在 (WC-01..WC-04)', () {
    testWidgets('四个窗口控制按钮均存在', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.minimize), findsOneWidget);
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('Resize 降级', () {
    testWidgets('isResizing 为 true 时 AnimatedOpacity 隐藏模糊层', (tester) async {
      await tester.pumpWidget(buildSubject());
      // BackdropFilter 始终挂载（避免树突变抖动），通过 AnimatedOpacity 控制可见性
      expect(find.byType(BackdropFilter), findsOneWidget);

      fake.isResizing.value = true;
      await tester.pump();

      // AnimatedOpacity opacity=0 时 GPU 跳过 compositing，BackdropFilter 不可见
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('isResizing 为 false 时 AnimatedOpacity 显示模糊层', (tester) async {
      await tester.pumpWidget(buildSubject());
      fake.isResizing.value = false;
      await tester.pump();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 1.0);
    });
  });

  group('Hover 状态恢复 (isResizing listener)', () {
    testWidgets('isResizing 从 true 变 false 时 hover 状态重置', (tester) async {
      await tester.pumpWidget(buildSubject());

      // 模拟：鼠标进入按钮区域 → hover = true
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byIcon(Icons.push_pin)),
      );
      await tester.pump();

      // 此时 isResizing = false，hover 应该生效
      // 按钮背景应该不是透明色（hover 高亮）
      // 检查 push_pin 图标的颜色 — hover 时应为 textPrimary
      final iconBefore = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(iconBefore.color, isNot(const Color(0xFF9999AA))); // 不是 textSecondary

      // 模拟 resize 开始 → isResizing = true
      fake.isResizing.value = true;
      await tester.pump();

      // isResizing listener 应在 resize 结束时重置 hover
      fake.isResizing.value = false;
      await tester.pump();

      // resize 结束后，_onResizingChanged 应将 _hovered 设为 false
      // 图标颜色应回到非 hover 状态
      final iconAfter = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      // 非 hover 状态: isActive=false → textSecondary
      expect(iconAfter.color, const Color(0xFF9999AA));
    });
  });
}
