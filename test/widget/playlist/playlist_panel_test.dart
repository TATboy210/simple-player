// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
/// 播放列表 UI 组件测试 (v0.0.5 竖条重设计).
///
/// PlaylistPanel 蔓延动画/条目 stagger/回调 + PlaylistTile 断点进度条/点击.
/// 数据源直接构造 ValueNotifier — 无需协调器与引擎.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/shared/glass_confirm_strip.dart';
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
    });

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
    });

    testWidgets('右键移除 → 确认条 → 确认后执行', (tester) async {
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
  });
}
