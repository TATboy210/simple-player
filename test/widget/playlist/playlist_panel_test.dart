/// 播放列表 UI 组件测试 (v0.0.5 竖条重设计).
///
/// PlaylistPanel 蔓延动画/条目 stagger/回调 + PlaylistTile 断点进度条/点击.
/// 数据源直接构造 ValueNotifier — 无需协调器与引擎.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
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
    late ValueNotifier<PlayMode> playMode;

    setUp(() {
      entries = ValueNotifier([
        PlaylistItem(path: 'a.mp4'),
        PlaylistItem(path: 'b.mp4'),
      ]);
      currentIndex = ValueNotifier(0);
      playMode = ValueNotifier(PlayMode.loopAll);
    });

    tearDown(() {
      entries.dispose();
      currentIndex.dispose();
      playMode.dispose();
    });

    Widget buildPanel({
      bool visible = true,
      void Function(int)? onPlayEntry,
      void Function(int)? onResumeEntry,
      void Function(int)? onRemoveEntry,
      VoidCallback? onCyclePlayMode,
      VoidCallback? onClose,
    }) => _wrap(
      PlaylistPanel(
        entries: entries,
        currentIndex: currentIndex,
        visible: visible,
        onClose: onClose ?? () {},
        onPlayEntry: onPlayEntry ?? (_) {},
        onResumeEntry: onResumeEntry ?? (_) {},
        onRemoveEntry: onRemoveEntry ?? (_) {},
        playMode: playMode,
        onCyclePlayMode: onCyclePlayMode ?? () {},
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
              onPlay: () => played++,
              onResume: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // 续播按钮禁用态 — 图标 alpha 减弱且不可点.
      final resumeButton = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.byIcon(Icons.replay),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(resumeButton.onTap, isNull);

      await tester.tap(find.byType(PlaylistTile));
      await tester.pump();
      expect(played, 1);
    });
  });
}
