// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
/// 播放列表 UI 组件测试 (v0.0.5 竖条重设计).
///
/// PlaylistPanel 蔓延动画/条目 stagger/回调 + PlaylistTile 断点进度条/点击.
/// 数据源直接构造 ValueNotifier — 无需协调器与引擎.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/shared/glass_confirm_strip.dart';
import 'package:simple_player_flutter/ui/shared/osd_service.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistPanel', () {
    late ValueNotifier<List<PlaylistItem>> entries;
    late ValueNotifier<int> currentIndex;
    late ValueNotifier<String?> lastPlayedPath;
    late ValueNotifier<PlayMode> playMode;

    setUp(() {
      entries = ValueNotifier([
        PlaylistItem(path: 'a.mp4'),
        PlaylistItem(path: 'b.mp4'),
      ]);
      currentIndex = ValueNotifier(0);
      lastPlayedPath = ValueNotifier<String?>(null);
      playMode = ValueNotifier(PlayMode.loopAll);
    });

    tearDown(() {
      entries.dispose();
      currentIndex.dispose();
      lastPlayedPath.dispose();
      playMode.dispose();
    });

    Widget buildPanel({
      bool visible = true,
      void Function(int)? onPlayEntry,
      void Function(int)? onResumeEntry,
      void Function(int)? onRemoveEntry,
      VoidCallback? onCyclePlayMode,
      VoidCallback? onClose,
      PlaylistSortKey sortKey = PlaylistSortKey.addedOrder,
      bool sortAscending = true,
      void Function(PlaylistSortKey)? onSortSelected,
      ValueListenable<bool>? scrubbing,
    }) => _wrap(
      PlaylistPanel(
        entries: entries,
        currentIndex: currentIndex,
        lastPlayedPath: lastPlayedPath,
        visible: visible,
        onClose: onClose ?? () {},
        onPlayEntry: onPlayEntry ?? (_) {},
        onResumeEntry: onResumeEntry ?? (_) {},
        onRemoveEntry: onRemoveEntry ?? (_) {},
        playMode: playMode,
        onCyclePlayMode: onCyclePlayMode ?? () {},
        sortKey: sortKey,
        sortAscending: sortAscending,
        onSortSelected: onSortSelected ?? (_) {},
        scrubbing: scrubbing,
      ),
    );

    testWidgets('初始不可见 — fade 时间轴为 0 且不响应命中', (tester) async {
      await tester.pumpWidget(buildPanel(visible: false));

      // IgnorePointer + FadeTransition(opacity 0) — 控制栏同款渐进渐退.
      // 面板自身 IgnorePointer 是其子树最浅层 (外部框架/子组件内也有).
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.descendant(
                of: find.byType(PlaylistPanel),
                matching: find.byType(IgnorePointer),
              ),
            )
            .first
            .ignoring,
        isTrue,
      );
      // 子组件 (GlassButton 等) 也有 FadeTransition — 面板自身的是最外层.
      final fade = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(PlaylistPanel),
              matching: find.byType(FadeTransition),
            ),
          )
          .first;
      expect(fade.opacity.value, 0);
    });

    testWidgets('blur 门控随 fade — 全隐态停用采样, 展开后启用 (v0.0.8.2)', (tester) async {
      await tester.pumpWidget(buildPanel(visible: false));
      await tester.pumpAndSettle();

      // 全隐态 (fade=0) — GlassBlurLayer 的 opacity 门控停用 GPU 背景采样.
      final backdrop = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(PlaylistPanel),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(backdrop.enabled, isFalse, reason: '隐藏期零合成成本');

      // 展开完成后 — 模糊启用.
      await tester.pumpWidget(buildPanel(visible: true));
      await tester.pumpAndSettle();
      final opened = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(PlaylistPanel),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(opened.enabled, isTrue);
      expect(find.byType(BackdropFilter), findsOneWidget, reason: '数量恒定契约');
    });

    testWidgets('seek 拖动挂起 — suspend 翻转停用/恢复 (v0.0.8.2)', (tester) async {
      final scrubbing = ValueNotifier<bool>(false);
      addTearDown(scrubbing.dispose);
      await tester.pumpWidget(buildPanel(visible: true, scrubbing: scrubbing));
      await tester.pumpAndSettle();

      final finder = find.descendant(
        of: find.byType(PlaylistPanel),
        matching: find.byType(BackdropFilter),
      );
      expect(tester.widget<BackdropFilter>(finder).enabled, isTrue);

      scrubbing.value = true;
      await tester.pump();
      expect(
        tester.widget<BackdropFilter>(finder).enabled,
        isFalse,
        reason: '拖动进度条期间挂起面板玻璃',
      );

      scrubbing.value = false;
      await tester.pump();
      expect(tester.widget<BackdropFilter>(finder).enabled, isTrue);
    });

    testWidgets('visible 翻转触发 forward 动画 — 最终完全显示', (tester) async {
      await tester.pumpWidget(buildPanel(visible: false));
      // 翻转可见性 — 状态动画需重建 widget 才触发 didUpdateWidget.
      await tester.pumpWidget(buildPanel(visible: true));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<IgnorePointer>(
              find.descendant(
                of: find.byType(PlaylistPanel),
                matching: find.byType(IgnorePointer),
              ),
            )
            .first
            .ignoring,
        isFalse,
      );
      // 子组件 (GlassButton 等) 也有 FadeTransition — 面板自身的是最外层.
      final fade = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(PlaylistPanel),
              matching: find.byType(FadeTransition),
            ),
          )
          .first;
      expect(fade.opacity.value, 1);
    });

    testWidgets('点击条目触发 onPlayEntry 并带索引', (tester) async {
      final played = <int>[];
      await tester.pumpWidget(buildPanel(onPlayEntry: played.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlaylistTile).at(1));
      await tester.pump();

      expect(played, [1]);
    });

    testWidgets('条目纵列渲染 — 索引高亮刷新不抛异常', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();

      currentIndex.value = 1;
      await tester.pump();

      expect(find.byType(PlaylistTile), findsNWidgets(2));
    });

    testWidgets('排序按钮 — 弹出菜单, 选择键触发 onSortSelected (v0.0.6)', (tester) async {
      final selected = <PlaylistSortKey>[];
      await tester.pumpWidget(buildPanel(onSortSelected: selected.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // 四个排序项齐全 (英文模板 — 测试 locale 未指定).
      expect(find.text('By Added Order'), findsOneWidget);
      expect(find.text('By Name'), findsOneWidget);
      expect(find.text('By Last Played'), findsOneWidget);
      expect(find.text('By Duration'), findsOneWidget);

      await tester.tap(find.text('By Name'));
      await tester.pumpAndSettle();
      expect(selected, [PlaylistSortKey.name]);
    });

    testWidgets('当前排序键勾选并显示方向箭头', (tester) async {
      await tester.pumpWidget(
        buildPanel(sortKey: PlaylistSortKey.name, sortAscending: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // 当前键唯一 — 勾选 + 降序箭头各一个.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    group('停止态高亮合成 (v0.0.6.2)', () {
      // 高亮可视断言锚点 — tile 名称色随状态翻转 (播放 accent / 锚点白 / 常规).
      Color nameColorOf(WidgetTester tester, String path) =>
          tester.widget<Text>(find.text(path)).style!.color!;

      testWidgets('停止态 (index=-1) + lastPlayedPath 命中 → 锚点白色高亮', (
        tester,
      ) async {
        currentIndex.value = -1;
        lastPlayedPath.value = 'b.mp4';
        await tester.pumpWidget(buildPanel());
        await tester.pump();

        // 锚点 = playlistAnchorWhite, 与播放态 accent 蓝区分状态语义.
        expect(nameColorOf(tester, 'b.mp4'), Tokens.playlistAnchorWhite);
        expect(nameColorOf(tester, 'a.mp4'), Tokens.textPrimary); // 其他不高亮
      });

      testWidgets('播放态 — accent 蓝, 锚不引发双高亮', (tester) async {
        currentIndex.value = 0; // 播放 a
        lastPlayedPath.value = 'b.mp4';
        await tester.pumpWidget(buildPanel());
        await tester.pump();

        expect(nameColorOf(tester, 'a.mp4'), Tokens.accent);
        expect(nameColorOf(tester, 'b.mp4'), Tokens.textPrimary);
      });

      testWidgets('播放态 currentIndex 命中 → 该条目 accent 蓝', (tester) async {
        currentIndex.value = 1;
        lastPlayedPath.value = null;
        await tester.pumpWidget(buildPanel());
        await tester.pump();

        expect(nameColorOf(tester, 'b.mp4'), Tokens.accent);
        expect(nameColorOf(tester, 'a.mp4'), Tokens.textPrimary);
      });

      testWidgets('lastPlayedPath 不匹配任何条目 → 无高亮', (tester) async {
        currentIndex.value = -1;
        lastPlayedPath.value = 'ghost.mp4';
        await tester.pumpWidget(buildPanel());
        await tester.pump();

        expect(nameColorOf(tester, 'a.mp4'), Tokens.textPrimary);
        expect(nameColorOf(tester, 'b.mp4'), Tokens.textPrimary);
      });

      testWidgets('hover 微亮 — 鼠标进入整卡背景泛白, 移出恢复', (tester) async {
        currentIndex.value = -1;
        await tester.pumpWidget(buildPanel());
        await tester.pump();

        Color? tileColorOf(String path) => switch (tester
            .widget<AnimatedContainer>(
              find
                  .ancestor(
                    of: find.text(path),
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            )
            .decoration) {
          final BoxDecoration box => box.color,
          _ => null,
        };

        expect(tileColorOf('a.mp4'), Colors.transparent); // 初始无 tint

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('a.mp4')));
        await tester.pumpAndSettle();

        expect(tileColorOf('a.mp4'), Tokens.glowHighlightWhite); // 微亮
        expect(tileColorOf('b.mp4'), Colors.transparent); // 兄弟条目不受影响

        await gesture.moveTo(Offset.zero); // 移出
        await tester.pumpAndSettle();
        expect(tileColorOf('a.mp4'), Colors.transparent);
      });
    });
  });

  group('PlaylistTile', () {
    testWidgets('有断点时续播按钮可用并触发 onResume', (tester) async {
      var resumed = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 280,
            child: PlaylistTile(
              item: PlaylistItem(
                path: 'a.mp4',
                positionMs: 30000,
                durationMs: 90000,
              ),
              isCurrent: false,
              isResumeAnchor: false,
              onPlay: () {},
              onResume: () => resumed++,
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // 续播按钮 (replay 图标) 可点.
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pump();
      expect(resumed, 1);
    });

    testWidgets('无断点时续播按钮禁用; 点击卡片触发 onPlay', (tester) async {
      var played = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 280,
            child: PlaylistTile(
              item: PlaylistItem(path: 'a.mp4'),
              isCurrent: false,
              isResumeAnchor: false,
              onPlay: () => played++,
              onResume: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // v0.0.5 塑料膜按钮: 续播分区禁用 — GestureDetector.onTap 为 null
      // (点击穿透无响应).
      final resumeGesture = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byIcon(Icons.replay),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(resumeGesture.onTap, isNull);

      await tester.tap(find.byType(PlaylistTile));
      await tester.pump();
      expect(played, 1);
    });

    testWidgets('resumeAllowed=false — 有断点也不显示进度区 (v0.0.6 门控)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 280,
            child: PlaylistTile(
              item: PlaylistItem(
                path: 'a.mp4',
                positionMs: 30000,
                durationMs: 90000,
              ),
              isCurrent: false,
              isResumeAnchor: false,
              onPlay: () {},
              onResume: () {},
              onRemove: () {},
              resumeAllowed: false, // 设置"记住播放位置"关闭
            ),
          ),
        ),
      );
      await tester.pump();

      // 断点进度条与"断点于"文字均不渲染; 续播分区禁用.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('断点于'), findsNothing);
      final resumeGesture = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byIcon(Icons.replay),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(resumeGesture.onTap, isNull);
    });
  });
  group('批量删除 (v0.0.7)', () {
    late ValueNotifier<List<PlaylistItem>> entries;
    Set<int>? removed;

    setUp(() {
      entries = ValueNotifier([
        PlaylistItem(path: 'a.mp4'),
        PlaylistItem(path: 'b.mp4'),
        PlaylistItem(path: 'c.mp4'),
      ]);
      removed = null;
      // 清残留 OSD — 断言以 OsdService.I.message 为准, 须从空白起步.
      OsdService.I.hide();
    });

    tearDown(OsdService.I.hide);

    Future<void> pumpBatchPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistPanel(
            entries: entries,
            currentIndex: ValueNotifier(-1),
            lastPlayedPath: ValueNotifier(null),
            visible: true,
            onClose: () {},
            onPlayEntry: (_) {},
            onResumeEntry: (_) {},
            onRemoveEntry: (_) {},
            onRemoveEntries: (indices) => removed = indices,
            playMode: ValueNotifier(PlayMode.loopAll),
            onCyclePlayMode: () {},
            sortKey: PlaylistSortKey.addedOrder,
            sortAscending: true,
            onSortSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('右键菜单含批量删除 — 点击进入多选模式并选中发起条', (tester) async {
      await pumpBatchPanel(tester);

      // 右键第二个条目
      await tester.tap(
        find.byType(PlaylistTile).at(1),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batch delete'));
      await tester.pumpAndSettle();

      // 操作条出现 + 发起条默认选中 → 全选按钮呈 deselect 态
      expect(find.byIcon(Icons.deselect), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('多选态点击切换选中 — 确认对话框执行批量移除', (tester) async {
      await pumpBatchPanel(tester);

      // 进入批量模式 (经右键菜单)
      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batch delete'));
      await tester.pumpAndSettle();

      // 点选第二、三条
      await tester.tap(find.byType(PlaylistTile).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PlaylistTile).at(2));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      // 删除 → 长条玻璃确认条 (正式文案)
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.byType(GlassConfirmStrip), findsOneWidget);
      expect(
        find.textContaining('will not delete any files from your local disk'),
        findsOneWidget,
      );

      // 确认删除 (danger 红方块按钮) → onRemoveEntries 收到全部选中索引
      await tester.tap(find.byIcon(Icons.delete).last);
      await tester.pumpAndSettle();
      expect(removed, equals({0, 1, 2}));
      expect(find.byIcon(Icons.deselect), findsNothing);
    });

    testWidgets('确认时目标已全部消失 — OSD 提示且不触发移除', (tester) async {
      await pumpBatchPanel(tester);

      // 进入批量模式 (经右键菜单) 并选中发起条之外的其余两条.
      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batch delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.deselect));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      // 打开确认条后队列被外部清空 — 同一 notifier 实例原地改值,
      // didUpdateWidget 的 identical 检查不触发取消, 确认卡悬于空队列上.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.byType(GlassConfirmStrip), findsOneWidget);
      entries.value = [];
      await tester.pumpAndSettle();

      // 确认 → 全部目标落空: 固定文案 OSD 轻提示, 移除回调不触发,
      // 批量模式已退出 (deselect 图标消失), 全程无异常.
      await tester.tap(find.byIcon(Icons.delete).last);
      await tester.pumpAndSettle();
      expect(
        OsdService.I.message.value?.text,
        'Entries are no longer in the playlist',
        reason: '落空确认须有 OSD 反馈',
      );
      expect(removed, isNull);
      expect(find.byIcon(Icons.deselect), findsNothing);

      // OSD hold 定时器在测试体结束时校验 — 体内显式取消 (tearDown 太晚).
      OsdService.I.hide();
    });

    testWidgets(
      'select all clears selection and deselected item stays excluded',
      (tester) async {
        await pumpBatchPanel(tester);
        await tester.tap(
          find.byType(PlaylistTile).first,
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Batch delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.deselect));
        await tester.pumpAndSettle();
        expect(find.text('3 selected'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.deselect));
        await tester.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);
        expect(find.byIcon(Icons.select_all), findsOneWidget);
        await tester.tap(find.byIcon(Icons.select_all));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PlaylistTile).at(1));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete).last);
        await tester.pumpAndSettle();
        expect(removed, {0, 2});
      },
    );

    testWidgets('取消退出多选模式 — 不触发移除', (tester) async {
      await pumpBatchPanel(tester);

      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batch delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.deselect), findsNothing);
      expect(removed, isNull);
    });
  });
  group('单条移除确认 (v0.0.7)', () {
    late ValueNotifier<List<PlaylistItem>> entries;
    int? removedIndex;

    setUp(() {
      entries = ValueNotifier([
        PlaylistItem(path: 'a.mp4'),
        PlaylistItem(path: 'b.mp4'),
      ]);
      removedIndex = null;
      // 清残留 OSD — 断言以 OsdService.I.message 为准, 须从空白起步.
      OsdService.I.hide();
    });

    tearDown(OsdService.I.hide);

    Future<void> pumpSinglePanel(WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistPanel(
            entries: entries,
            currentIndex: ValueNotifier(-1),
            lastPlayedPath: ValueNotifier(null),
            visible: true,
            onClose: () {},
            onPlayEntry: (_) {},
            onResumeEntry: (_) {},
            onRemoveEntry: (index) => removedIndex = index,
            onRemoveEntries: (_) {},
            playMode: ValueNotifier(PlayMode.loopAll),
            onCyclePlayMode: () {},
            sortKey: PlaylistSortKey.addedOrder,
            sortAscending: true,
            onSortSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('右键移除 → 确认条 → 确认后执行', (tester) async {
      await pumpSinglePanel(tester);

      // 右键第一条 → 菜单 Remove
      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // 确认条出现 (计数 1) — 未确认前不执行
      expect(find.byType(GlassConfirmStrip), findsOneWidget);
      expect(removedIndex, isNull);

      // 取消 — 不执行
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(removedIndex, isNull);

      // 再走一次 → 确认
      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete).last);
      await tester.pumpAndSettle();

      expect(removedIndex, equals(0));
    });

    testWidgets('确认时目标已消失 — OSD 提示且不触发移除', (tester) async {
      await pumpSinglePanel(tester);

      // 右键第一条 → Remove → 确认条打开 (未确认前不执行).
      await tester.tap(
        find.byType(PlaylistTile).at(0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassConfirmStrip), findsOneWidget);

      // 确认前队列被外部清空 — 确认卡悬于空队列上 (同一 notifier 实例).
      entries.value = [];
      await tester.pumpAndSettle();

      // 确认 → 唯一目标落空: 固定文案 OSD 轻提示, removedIndex 不触发.
      await tester.tap(find.byIcon(Icons.delete).last);
      await tester.pumpAndSettle();
      expect(
        OsdService.I.message.value?.text,
        'Entries are no longer in the playlist',
        reason: '落空确认须有 OSD 反馈',
      );
      expect(removedIndex, isNull);

      // OSD hold 定时器在测试体结束时校验 — 体内显式取消 (tearDown 太晚).
      OsdService.I.hide();
    });
  });

  group('滚轮平滑滚动 (v0.0.11 T4)', () {
    // 20 条 × ~124px 远超视口高度 — 保证有真实滚动余量 (maxScrollExtent > 0).
    late ValueNotifier<List<PlaylistItem>> entries;
    int? playedIndex;

    setUp(() {
      entries = ValueNotifier([
        for (var i = 0; i < 20; i++) PlaylistItem(path: 'wheel-$i.mp4'),
      ]);
      playedIndex = null;
    });

    tearDown(() {
      entries.dispose();
    });

    Future<void> pumpWheelPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistPanel(
            entries: entries,
            currentIndex: ValueNotifier(-1),
            lastPlayedPath: ValueNotifier(null),
            visible: true,
            onClose: () {},
            onPlayEntry: (i) => playedIndex = i,
            onResumeEntry: (_) {},
            onRemoveEntry: (_) {},
            playMode: ValueNotifier(PlayMode.loopAll),
            onCyclePlayMode: () {},
            sortKey: PlaylistSortKey.addedOrder,
            sortAscending: true,
            onSortSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// 面板内唯一 Scrollable 的滚动位置 — offset 观察口.
    ScrollPosition scrollPosition(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    /// 鼠标指针悬停到列表中心 (滚轮事件按 position 命中测试, 须先落位).
    Future<TestPointer> hoverListCenter(WidgetTester tester) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(Scrollable))),
      );
      return pointer;
    }

    testWidgets('滚轮 tick 后滑行 — 存在严格介于起点与目标之间的采样帧', (tester) async {
      await pumpWheelPanel(tester);
      final position = scrollPosition(tester);
      expect(position.pixels, 0);

      final pointer = await hoverListCenter(tester);
      await tester.pump();

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      final start = position.pixels;
      // 动画帧时序不可精确断言 — 放宽为多帧采样存在中间帧 (断言语义不变:
      // 证明非瞬跳). 瞬跳行为 (flutter#31658 forcePixels) 采样恒等于目标 → 红.
      final samples = <double>[];
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 24));
        samples.add(position.pixels);
      }
      expect(
        samples.any((o) => o > start && o < start + 120),
        isTrue,
        reason: '滑行动画必有中间帧; 瞬跳则采样恒等于目标',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('pumpAndSettle 后到达 clamp 目标 — 不越界', (tester) async {
      await pumpWheelPanel(tester);
      final position = scrollPosition(tester);

      final pointer = await hoverListCenter(tester);
      await tester.pump();

      // 巨型 delta — 目标钳到 maxScrollExtent, 终点不得越界.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100000)));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
    });

    testWidgets('连发 3 tick — offset 单调不减且最终不越界', (tester) async {
      await pumpWheelPanel(tester);
      final position = scrollPosition(tester);

      final pointer = await hoverListCenter(tester);
      await tester.pump();

      final samples = <double>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
        await tester.pump(const Duration(milliseconds: 60));
        samples.add(position.pixels);
      }
      // 单调不减 — 连发滚轮连续滑行, 不回退不抖动.
      expect(samples[0] <= samples[1] && samples[1] <= samples[2], isTrue);

      await tester.pumpAndSettle();
      expect(position.pixels, greaterThanOrEqualTo(samples.last));
      expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
    });

    testWidgets('回归 — 拖拽滚动行为不变', (tester) async {
      await pumpWheelPanel(tester);
      final position = scrollPosition(tester);

      // 拖拽走手势竞技场 (down/up 事件), 与 pointer signal 无关.
      // 多段小步 move + 逐帧 pump — 单次大步 move 不触发 drag 识别器.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Scrollable)),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
    });

    testWidgets('回归 — 滚轮后点击条目仍触发播放', (tester) async {
      await pumpWheelPanel(tester);

      final pointer = await hoverListCenter(tester);
      await tester.pump();
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();

      // 滚轮介入后条目点击链路 (手势竞技场 down/up) 不受影响.
      await tester.tap(find.byType(PlaylistTile).first);
      await tester.pumpAndSettle();
      expect(playedIndex, isNotNull);
    });
  });

  group('关闭态焦点排除 (v0.0.12 U1)', () {
    // U1: PlaylistPanel 常驻挂载 — 关闭态只有 IgnorePointer(挡指针)而无
    // ExcludeFocus(挡焦点), Tab 遍历可落入不可见 tile 触发器/排序/模式/
    // 关闭按钮, Space/Enter 触发"幽灵动作"(播放条目/切播放模式/关面板 —
    // 均为持久状态副作用). 修复: 照 SettingsPanel(settings_panel.dart:422)
    // 对照写法, 与 IgnorePointer 并列挂 ExcludeFocus(excluding: !visible).
    late ValueNotifier<List<PlaylistItem>> entries;
    late ValueNotifier<int> currentIndex;
    late ValueNotifier<String?> lastPlayedPath;
    late ValueNotifier<PlayMode> playMode;
    int playCount = 0;
    int cycleCount = 0;
    int closeCount = 0;

    setUp(() {
      entries = ValueNotifier([
        PlaylistItem(path: 'a.mp4'),
        PlaylistItem(path: 'b.mp4'),
      ]);
      currentIndex = ValueNotifier(-1);
      lastPlayedPath = ValueNotifier(null);
      playMode = ValueNotifier(PlayMode.loopAll);
      playCount = 0;
      cycleCount = 0;
      closeCount = 0;
    });

    tearDown(() {
      entries.dispose();
      currentIndex.dispose();
      lastPlayedPath.dispose();
      playMode.dispose();
    });

    Future<void> pumpClosedPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistPanel(
            entries: entries,
            currentIndex: currentIndex,
            lastPlayedPath: lastPlayedPath,
            visible: false,
            onClose: () => closeCount++,
            onPlayEntry: (_) => playCount++,
            onResumeEntry: (_) {},
            onRemoveEntry: (_) {},
            playMode: playMode,
            onCyclePlayMode: () => cycleCount++,
            sortKey: PlaylistSortKey.addedOrder,
            sortAscending: true,
            onSortSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// 焦点判据 — primaryFocus 的 element 沿祖先链是否命中面板 element.
    ///
    /// 关闭态焦点排除的核心观测点: 焦点节点挂在 Focus widget 上,
    /// 其 context 必然是面板子树内的 element (焦点在面板外/无焦点 → false).
    bool isFocusInsidePanel() {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext is! Element) return false;
      final panel = find.byType(PlaylistPanel).evaluate().single;
      if (identical(focusContext, panel)) return true;
      var inside = false;
      focusContext.visitAncestorElements((e) {
        if (identical(e, panel)) inside = true;
        return true;
      });
      return inside;
    }

    testWidgets('Tab 遍历不落入关闭面板 — 焦点恒在面板子树之外', (tester) async {
      await pumpClosedPanel(tester);

      // 15 次 Tab — 覆盖面板全部可聚焦节点(tile 触发器 + 排序/模式/
      // 关闭按钮)并回绕; 修复前遍历落入不可见控件, 本断言红.
      for (var i = 0; i < 15; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(
        isFocusInsidePanel(),
        isFalse,
        reason: '关闭面板必须排除出焦点遍历(ExcludeFocus) — '
            'Tab 落入不可见控件即幽灵焦点',
      );
    });

    testWidgets('关闭面板控件被聚焦时 Space/Enter 无幽灵动作', (tester) async {
      await pumpClosedPanel(tester);

      // 直接把焦点钉到面板内 tile 触发器(模拟修复前 Tab 漏入的落点),
      // 再按 Space/Enter: 修复前激活播放 → 红; 修复后 ExcludeFocus 令
      // 子树不可聚焦, requestFocus 成 no-op, 两键无落点, 断言恒绿.
      final tileTrigger = tester
          .widgetList<Focus>(
            find.descendant(
              of: find.byType(PlaylistTile).first,
              matching: find.byType(Focus),
            ),
          )
          .map((f) => f.focusNode)
          .whereType<FocusNode>()
          .first;
      tileTrigger.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(playCount, 0, reason: '关闭面板不得被键盘激活播放条目');
      expect(cycleCount, 0, reason: '关闭面板不得被键盘切换播放模式(持久状态)');
      expect(closeCount, 0, reason: '关闭面板不得被键盘触发关闭回调');
    });
  });
}
