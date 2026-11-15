// ignore_for_file: no-empty-block
/// 播放列表拆分后各子组件的独立 widget 测试 (无引擎/协调器依赖).
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_entry_list.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_film_button.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel_headers.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_thumb_box.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile_info.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tokens.dart';
import '../../helpers/l10n_delegates.dart' show l10nDelegates;

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: l10nDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

void main() {
  group('PlaylistBatchHeader', () {
    testWidgets('delete disabled at zero selection, enabled otherwise', (
      tester,
    ) async {
      var deletes = 0;
      Widget build(int count) => _wrap(
        PlaylistBatchHeader(
          selectedCount: count,
          onToggleSelectAll: () {},
          onDelete: () => deletes++,
          onCancel: () {},
        ),
      );
      await tester.pumpWidget(build(0));
      // 禁用按钮被 IgnorePointer 吞掉点击 — 命中警告属预期.
      await tester.tap(find.byIcon(Icons.delete_outline), warnIfMissed: false);
      await tester.pump();
      expect(deletes, 0);
      expect(find.byIcon(Icons.select_all), findsOneWidget);

      await tester.pumpWidget(build(2));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(deletes, 1);
      expect(find.byIcon(Icons.deselect), findsOneWidget);
    });
  });

  group('PlaylistTileInfo', () {
    testWidgets('shows name, hides progress and retry by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistTileInfo(
            name: 'movie.mp4',
            nameColor: Colors.white,
            showRetry: false,
            onRetry: () {},
            resumeProgress: null,
            positionMs: 0,
          ),
        ),
      );
      expect(find.text('movie.mp4'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(PlaylistRetryButton), findsNothing);
    });

    testWidgets('retry button fires and progress bar renders value', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _wrap(
          PlaylistTileInfo(
            name: 'movie.mp4',
            nameColor: Colors.white,
            showRetry: true,
            onRetry: () => retries++,
            resumeProgress: 0.5,
            positionMs: 65000,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.refresh_outlined));
      expect(retries, 1);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
      expect(bar.minHeight, PlaylistTokens.resumeBarHeight);
    });
  });

  group('PlaylistThumbBox', () {
    testWidgets('selection mode shows badge and no film layer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaylistThumbBox(
            thumbnail: const ColoredBox(color: Colors.black),
            selectionMode: true,
            isSelected: true,
            canResume: true,
            onPlay: () {},
            onResume: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(PlaylistFilmButton), findsNothing);
    });

    testWidgets('normal mode: two film buttons, resume gated by canResume', (
      tester,
    ) async {
      var plays = 0;
      var resumes = 0;
      await tester.pumpWidget(
        _wrap(
          PlaylistThumbBox(
            thumbnail: const ColoredBox(color: Colors.black),
            selectionMode: false,
            isSelected: false,
            canResume: false,
            onPlay: () => plays++,
            onResume: () => resumes++,
          ),
        ),
      );
      expect(find.byType(PlaylistFilmButton), findsNWidgets(2));
      final box = tester.getRect(find.byType(PlaylistThumbBox));
      // 上 3/5 播放区 / 下 2/5 续播区 (禁用).
      await tester.tapAt(Offset(box.center.dx, box.top + box.height * 0.2));
      await tester.tapAt(Offset(box.center.dx, box.top + box.height * 0.9));
      await tester.pump();
      expect(plays, 1);
      expect(resumes, 0);
    });
  });

  group('PlaylistEntryList', () {
    testWidgets('out-of-range batch selection is filtered, no crash', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final items = [PlaylistItem(path: 'a.mp4'), PlaylistItem(path: 'b.mp4')];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 300,
            child: PlaylistEntryList(
              items: items,
              currentIndex: -1,
              lastPlayed: 'b.mp4',
              resumeAllowed: true,
              controller: controller,
              onPointerSignal: (_) {},
              batchMode: true,
              batchSelected: const {1, 99, -3},
              onPlay: (_) {},
              onResume: (_) {},
              onRemove: (_) {},
              onToggleSelect: (_) {},
              onStartBatchSelect: null,
            ),
          ),
        ),
      );
      await tester.pump();
      // 只有合法索引 1 被选中.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });
  });
}
