// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// 设置面板停靠化 + XMB 化 (v0.0.8) 行为契约 —
/// 面板挂载于控制层 Stack 中列槽位（与播放列表同层，非 route）：
/// 宽 = 槽位/3、高撑满、位置恒定（不随播放列表开关变化）；
/// 键盘交叉导航（面板开着方向键不触发 seek，关闭后归还宿主）。
/// 与 lifecycle 测试同尺寸: 槽位居中后四周仍有面板外区域可点.
const Size surface = Size(1280, 720);

/// 槽位宽 = 窗口 - 左右 margin; 面板宽 = 槽位/3 (恒定, 与播放列表无关).
double expectedPanelWidth() =>
    (surface.width - 2 * Tokens.controlBarMarginH) / 3;

void main() {
  /// [playlistVisible] 非 null 时同时装配播放列表 (coordinator 内部创建,
  /// 纯内存 store) — 位置恒定用例需要真实接线.
  Future<void> pumpControls(
    WidgetTester tester,
    ValueNotifier<bool> settingsVisible, {
    bool initialVisible = false,
    ValueNotifier<bool>? playlistVisible,
    PlayerActions? actions,
    bool withEmptyState = false,
    VoidCallback? onOpenFile,
  }) async {
    settingsVisible.value = initialVisible;
    final video = FakeVideoControlsPort(player: FakePlayerControls());
    final engine = FakeEngine();
    addTearDown(video.dispose);
    addTearDown(engine.dispose);
    final coordinator = playlistVisible == null
        ? null
        : PlaylistCoordinator(engine: engine);
    if (coordinator != null) addTearDown(coordinator.dispose);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        // 固定 zh — 英文摘要在 Ahem 字体下必超宽, 会启动跑马灯 repeat 使
        // pumpAndSettle 死循环 (SDK 无 timeout); 中文摘要不溢出全静止.
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: surface.width,
            height: surface.height,
            child: PlayerVideoControls(
              video: video,
              engine: engine,
              actions: actions ?? const PlayerActions(),
              currentFileName: ValueNotifier<String>('a.mp4'),
              windowMode: ValueNotifier<WindowMode>(WindowMode.windowed),
              playlistVisible: playlistVisible,
              playlistCoordinator: coordinator,
              settingsVisible: settingsVisible,
              emptyState: withEmptyState
                  ? EmptyState(engineState: engine.state, onOpenFile: onOpenFile)
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('设置面板常驻挂载于控制层 Stack 且无 route barrier', (tester) async {
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(tester, settingsVisible);

    // 非 route 弹层: 面板树常驻 (隐藏期 IgnorePointer + opacity 0)。
    // MaterialApp home route 自带 1 个无色 barrier (探针实证), 锁定打开
    // 前后 barrier 不新增 — 旧 showDialog 方案下会 +1 全屏拦截层, 此为
    // 标题栏拖动不被拦截的结构契约.
    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.byType(ModalBarrier), findsOneWidget);

    settingsVisible.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPanel), findsOneWidget);
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

  testWidgets('三等分: 面板宽=槽位/3 高撑满且位置恒定 (播放列表开关不移动)', (tester) async {
    final settingsVisible = ValueNotifier<bool>(true);
    final playlistVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    addTearDown(playlistVisible.dispose);
    await pumpControls(
      tester,
      settingsVisible,
      playlistVisible: playlistVisible,
    );

    // 播放列表关闭: 面板恒在中列 (右缘贴播放列表槽位左侧 spMd),
    // 宽 = 槽位/3, 高撑满槽位.
    final closedRect = tester.getRect(find.byType(SettingsPanel));
    expect(closedRect.width, closeTo(expectedPanelWidth(), 0.5));
    expect(closedRect.height, closeTo(surface.height - 12 - 138, 0.5));
    // 与播放列表槽位的呼吸距 (spMd) — 播放列表关闭时右缘同样恒定.
    expect(
      surface.width -
          Tokens.controlBarMarginH -
          PlaylistPanel.panelWidth -
          closedRect.right,
      closeTo(Tokens.spMd, 0.5),
    );

    // 播放列表打开: 面板位置与尺寸完全不变 (恒定中列, 无动态避让).
    playlistVisible.value = true;
    await tester.pumpAndSettle();
    final openRect = tester.getRect(find.byType(SettingsPanel));
    expect(openRect, closedRect);

    // 与真实播放列表 Rect 不相交.
    final playlistRect = tester.getRect(find.byType(PlaylistPanel));
    expect(playlistRect.left - openRect.right, closeTo(Tokens.spMd, 0.5));
    expect(openRect.overlaps(playlistRect), isFalse);

    // tag 居中对称: chip 撑满面板内容区 (宽 = 面板 - 壳 border 2px - 2×spLg),
    // 左缘 = 面板 left + border 1px + spLg (离开面板圆角区).
    final chipRect = tester.getRect(
      find.byKey(const ValueKey('settings-tab-general')),
    );
    expect(
      chipRect.width,
      closeTo(closedRect.width - 2 * Tokens.spLg - 2, 0.5),
    );
    expect(chipRect.left, closeTo(closedRect.left + Tokens.spLg + 1, 0.5));
  });

  testWidgets('空置态: 面板外点击关闭浮层面板 (设置优先于播放列表)', (tester) async {
    final settingsVisible = ValueNotifier<bool>(true);
    final playlistVisible = ValueNotifier<bool>(true);
    addTearDown(settingsVisible.dispose);
    addTearDown(playlistVisible.dispose);
    await pumpControls(
      tester,
      settingsVisible,
      playlistVisible: playlistVisible,
      withEmptyState: true,
    );
    // pump 后开面板 (initialVisible 默认 false — 面板先关着再打开).
    settingsVisible.value = true;
    await tester.pump(const Duration(milliseconds: 300));

    // 空置态手势层不再整体禁用 — 面板外点击走仅关面板回调 (设置优先).
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settingsVisible.value, isFalse);
    expect(playlistVisible.value, isTrue);

    // 再点 → 关播放列表.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(playlistVisible.value, isFalse);
  });

  testWidgets('空置态: 面板矩形内点击不关闭 (背景装饰吸收)', (tester) async {
    final settingsVisible = ValueNotifier<bool>(true);
    addTearDown(settingsVisible.dispose);
    await pumpControls(tester, settingsVisible, withEmptyState: true);
    settingsVisible.value = true;
    await tester.pump(const Duration(milliseconds: 300));

    final panelRect = tester.getRect(find.byType(SettingsPanel));
    await tester.tapAt(Offset(panelRect.left + 10, panelRect.bottom - 30));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settingsVisible.value, isTrue, reason: '面板矩形内背景吸收, 不触发点外关闭');
  });

  testWidgets('空置态无面板: 中央"打开文件"按钮可点 (fb9d383f 回归)', (tester) async {
    // 根因: 空置态手势层 onTap 恒非 null → TapGestureRecognizer 恒注册 →
    // translucent GD 参与竞技场且先注册先赢, 底层按钮 InkWell 被拒.
    // 契约: 手势层必须让位 (onTap=null 不参战), 按钮回调触发.
    var openCalls = 0;
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(
      tester,
      settingsVisible,
      withEmptyState: true,
      onOpenFile: () => openCalls++,
    );

    // 空置态中央按钮 (EmptyState 内 GlassButton, folder_open 图标定位).
    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pump(const Duration(milliseconds: 300));
    expect(openCalls, 1, reason: '无面板时手势层让位, 按钮回调必须触发');
  });

  testWidgets('空置态面板开着: 面板外点击只关面板不触发按钮', (tester) async {
    var openCalls = 0;
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(
      tester,
      settingsVisible,
      withEmptyState: true,
      onOpenFile: () => openCalls++,
    );
    settingsVisible.value = true;
    await tester.pump(const Duration(milliseconds: 300));

    // 面板外点击 → 手势层活跃 (onTap=_handleEmptyAreaTap) 关面板,
    // 不应穿透到中央按钮.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settingsVisible.value, isFalse);
    expect(openCalls, 0, reason: '关面板点击不得误触打开文件按钮');
  });

  testWidgets('面板开着方向键被面板消费不触发 seek, 关面板后归还宿主', (tester) async {
    var seekCalls = 0;
    final settingsVisible = ValueNotifier<bool>(false);
    addTearDown(settingsVisible.dispose);
    await pumpControls(
      tester,
      settingsVisible,
      actions: PlayerActions(
        onSeekBack: (_) => seekCalls++,
        onSeekForward: (_) => seekCalls++,
      ),
    );

    settingsVisible.value = true;
    await tester.pumpAndSettle();

    // L0: ← handled 空操作 (不冒泡 seek) — C5 契约.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(seekCalls, 0, reason: 'L0 的 ← 不得泄漏为 seek');

    // → 进入内容层 (L1)。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // L1: ← 返回 tag 层 (新语义), 仍不泄漏 seek.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(seekCalls, 0, reason: 'L1 的 ← 不得泄漏为 seek');

    // 关闭面板: 宿主归还焦点, ← 恢复为 seek (E1 焦点归还契约).
    settingsVisible.value = false;
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(seekCalls, 1, reason: '关面板后方向键必须恢复 seek (焦点归还)');
  });
}
