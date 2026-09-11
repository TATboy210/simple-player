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
        onRemoveEntry: onRemoveEntry ?? (_) {},
        playMode: playMode,
        onCyclePlayMode: onCyclePlayMode ?? () {},
      ),
    );

    testWidgets('初始不可见 — 蔓延时间轴为 0 (widthFactor 零宽)', (tester) async {
      await tester.pumpWidget(buildPanel(visible: false));

      // Align widthFactor 由 controller 驱动 — 初始 value=0 → 零宽无命中.
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.widthFactor, 0);
    });

    testWidgets('visible 翻转触发 forward 动画 — 最终完全展开', (tester) async {
      await tester.pumpWidget(buildPanel(visible: false));
      // 翻转可见性 — 状态动画需重建 widget 才触发 didUpdateWidget.
      await tester.pumpWidget(buildPanel(visible: true));
      await tester.pumpAndSettle();

      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.widthFactor, 1);
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
    testWidgets('断点进度条在 position/duration 齐备时渲染', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: PlaylistTile(
              item: PlaylistItem(
                path: 'a.mp4',
                positionMs: 30000,
                durationMs: 90000,
              ),
              isCurrent: false,
              onPlay: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(1 / 3, 0.001),
      );
    });

    testWidgets('无断点时不渲染进度条; 点击触发 onPlay', (tester) async {
      var played = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: PlaylistTile(
              item: PlaylistItem(path: 'a.mp4'),
              isCurrent: false,
              onPlay: () => played++,
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(find.byType(PlaylistTile));
      await tester.pump();
      expect(played, 1);
    });
  });
}
