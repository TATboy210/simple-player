// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_dialog.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// 设置面板 Stack 化 (v0.0.7.1) 行为契约 —
/// 面板挂载于控制层 Stack（非 route），打开时标题栏拖动不被 barrier 拦截。
void main() {
  // 与 lifecycle 测试同尺寸: 面板 620x440 居中后四周仍有面板外区域可点.
  const surface = Size(1280, 720);

  Future<void> pumpControls(
    WidgetTester tester,
    ValueNotifier<bool> settingsVisible, {
    bool initialVisible = false,
  }) async {
    settingsVisible.value = initialVisible;
    final video = FakeVideoControlsPort(player: FakePlayerControls());
    final engine = FakeEngine();
    addTearDown(video.dispose);
    addTearDown(engine.dispose);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: surface.width,
            height: surface.height,
            child: PlayerVideoControls(
              video: video,
              engine: engine,
              actions: const PlayerActions(),
              currentFileName: ValueNotifier<String>('a.mp4'),
              windowMode: ValueNotifier<WindowMode>(WindowMode.windowed),
              settingsVisible: settingsVisible,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('设置面板常驻挂载于控制层 Stack 且无 route barrier', (tester) async {
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(tester, settingsVisible);

    // 非 route 弹层: 面板树常驻 (隐藏期 IgnorePointer + opacity 0)。
    // MaterialApp home route 自带 1 个无色 barrier (探针实证), 锁定打开
    // 前后 barrier 不新增 — 旧 showDialog 方案下会 +1 全屏拦截层, 此为
    // 标题栏拖动不被拦截的结构契约.
    expect(find.byType(SettingsDialog), findsOneWidget);
    expect(find.byType(ModalBarrier), findsOneWidget);

    settingsVisible.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDialog), findsOneWidget);
    expect(find.byType(ModalBarrier), findsOneWidget);
  });

  testWidgets('设置面板可见时点击视频区(面板外)关闭面板', (tester) async {
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(tester, settingsVisible);

    settingsVisible.value = true;
    await tester.pumpAndSettle();
    expect(settingsVisible.value, isTrue);

    // 面板外左上角点击 → _handleTap 点外关闭分支, 不触发双击全屏判定.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(settingsVisible.value, isFalse);
  });
}
