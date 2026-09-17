/// 播放列表 UI 组件测试 (v0.0.5 竖条重设计).
///
/// PlaylistPanel 蔓延动画/条目 stagger/回调 + PlaylistTile 断点进度条/点击.
/// 数据源直接构造 ValueNotifier — 无需协调器与引擎.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
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

    testWidgets('排序按钮 — 弹出菜单, 选择键触发 onSortSelected (v0.0.6)',
        (tester) async {
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

        Color? tileColorOf(String path) => switch (
          tester
              .widget<AnimatedContainer>(
                find
                    .ancestor(
                      of: find.text(path),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .decoration
        ) {
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

    testWidgets('resumeAllowed=false — 有断点也不显示进度区 (v0.0.6 门控)',
        (tester) async {
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
}
