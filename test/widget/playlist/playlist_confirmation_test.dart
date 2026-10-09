import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile.dart';
import 'package:simple_player_flutter/ui/shared/glass_confirm_strip.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  for (final action in [
    'confirm',
    'cancel',
    'escape',
    'hide',
    'unmount',
    'vanish',
    'duplicate',
    'batch',
    'replace',
    'default-enter',
    'tab-confirm',
  ]) {
    testWidgets('panel-local frozen target: $action', (tester) async {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final entries = ValueNotifier([a, b]);
      final index = ValueNotifier(0);
      final last = ValueNotifier<String?>(null);
      final mode = ValueNotifier(PlayMode.loopAll);
      for (final source in [entries, index, last, mode]) {
        addTearDown(source.dispose);
      }
      final removed = <int>[];
      final batches = <Set<int>>[];
      var outside = 0;
      var fullscreenExits = 0;
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      Widget subject(bool visible) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorkspaceMenuScope(
            session: menus,
            onEscape: () => fullscreenExits++,
            child: KeyboardHandler(
              menuSession: menus,
              onExitFullscreen: () => fullscreenExits++,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => outside++,
                    child: const Text('outside'),
                  ),
                  SizedBox(
                    height: 200,
                    child: PlaylistPanel(
                      entries: entries,
                      currentIndex: index,
                      lastPlayedPath: last,
                      visible: visible,
                      onClose: () {},
                      onPlayEntry: (_) {},
                      onResumeEntry: (_) {},
                      onRemoveEntry: removed.add,
                      onRemoveEntries: batches.add,
                      playMode: mode,
                      onCyclePlayMode: () {},
                      sortKey: PlaylistSortKey.addedOrder,
                      sortAscending: true,
                      onSortSelected: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(true));
      await tester.pumpAndSettle();
      final barriers = find.byType(ModalBarrier).evaluate().length;
      final panelRect = tester.getRect(find.byType(PlaylistPanel));
      if (action == 'batch') {
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).first)
            .onStartBatchSelect
            ?.call();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Confirm deletion'));
      } else {
        tester.widget<PlaylistTile>(find.byType(PlaylistTile).first).onRemove();
      }
      await tester.pumpAndSettle();
      expect(find.byType(GlassConfirmStrip), findsOneWidget);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barriers,
        reason: 'no root modal',
      );
      final cardRect = tester.getRect(find.byType(GlassConfirmStrip));
      expect(cardRect.center.dx, closeTo(panelRect.center.dx, 0.1));
      expect(cardRect.center.dy, closeTo(panelRect.center.dy, 0.1));
      expect(panelRect.contains(cardRect.topLeft), isTrue);
      expect(panelRect.contains(cardRect.bottomRight), isTrue);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'playlist-confirm-cancel',
      );
      if (action != 'default-enter' && action != 'tab-confirm') {
        await tester.tap(find.text('outside'));
        expect(outside, 1);
      }
      if (action == 'batch') {
        // Change the selection after opening: the confirmed target remains a.
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).first)
            .onToggleSelect
            ?.call();
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).last)
            .onToggleSelect
            ?.call();
      }
      if (action == 'replace') {
        tester.widget<PlaylistTile>(find.byType(PlaylistTile).last).onRemove();
        await tester.pumpAndSettle();
      }
      entries.value = action == 'vanish'
          ? [b]
          : action == 'duplicate'
          ? [a, a, b]
          : [b, a];
      await tester.pump();
      switch (action) {
        case 'hide':
          await tester.pumpWidget(subject(false));
        case 'unmount':
          await tester.pumpWidget(const SizedBox.shrink());
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'cancel':
          await tester.tap(find.byTooltip('Cancel'));
        case 'default-enter':
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        case 'tab-confirm':
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
        default:
          await tester.tap(
            find.descendant(
              of: find.byType(GlassConfirmStrip),
              matching: find.byTooltip('Confirm deletion'),
            ),
          );
      }
      await tester.pumpAndSettle();
      expect(
        removed,
        action == 'confirm' || action == 'tab-confirm'
            ? [1]
            : action == 'replace'
            ? [0]
            // H3 修复: duplicate 分支期望由 isEmpty 翻转为 [0] — 旧断言编码的
            // 正是"重复即歧义、确认也不删"这一被本修复推翻的 bug 语义; 新语义
            // 下冻结位 0 的 a 在 [a, a, b] 中仍居位 0, 确认后精确删除被点格。
            : action == 'duplicate'
            ? [0]
            : isEmpty,
      );
      expect(
        batches,
        action == 'batch'
            ? [
                {1},
              ]
            : isEmpty,
      );
      expect(find.byType(GlassConfirmStrip), findsNothing);
      expect(
        fullscreenExits,
        0,
        reason: 'confirmation ESC must not exit fullscreen',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  group('duplicate-path targets', () {
    // H3 修复面板级场景 — a 以同一实例注入两次, 复现 _itemFor path 级缓存
    // 下的生产孪生形态 (path 与 addedSeq 完全相同)。
    Future<void> pumpPanel(
      WidgetTester tester, {
      required ValueNotifier<List<PlaylistItem>> entries,
      required List<int> removed,
      required List<Set<int>> batches,
    }) async {
      final index = ValueNotifier(0);
      final last = ValueNotifier<String?>(null);
      final mode = ValueNotifier(PlayMode.loopAll);
      for (final source in [entries, index, last, mode]) {
        addTearDown(source.dispose);
      }
      final menus = WorkspaceMenuSession();
      addTearDown(menus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceMenuScope(
              session: menus,
              onEscape: () {},
              child: KeyboardHandler(
                menuSession: menus,
                onExitFullscreen: () {},
                child: SizedBox(
                  height: 600,
                  child: PlaylistPanel(
                    entries: entries,
                    currentIndex: index,
                    lastPlayedPath: last,
                    visible: true,
                    onClose: () {},
                    onPlayEntry: (_) {},
                    onResumeEntry: (_) {},
                    onRemoveEntry: removed.add,
                    onRemoveEntries: batches.add,
                    playMode: mode,
                    onCyclePlayMode: () {},
                    sortKey: PlaylistSortKey.addedOrder,
                    sortAscending: true,
                    onSortSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 确认条内的确认按钮 — 批量模式下与头部删除按钮同 tooltip, 必须按
    // GlassConfirmStrip 子树作用域查找。
    Finder confirmInStrip() => find.descendant(
      of: find.byType(GlassConfirmStrip),
      matching: find.byTooltip('Confirm deletion'),
    );

    testWidgets(
      'single removal pops the card and deletes exactly the tapped twin',
      (tester) async {
        final a = PlaylistItem(path: 'a.mp4');
        final b = PlaylistItem(path: 'b.mp4');
        final removed = <int>[];
        final batches = <Set<int>>[];
        await pumpPanel(
          tester,
          entries: ValueNotifier([a, a, b]),
          removed: removed,
          batches: batches,
        );
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).first)
            .onRemove();
        await tester.pumpAndSettle();
        // 修复前: 重复 path 索引被构造器整体丢弃 → 此处不弹卡、静默返回。
        expect(find.byType(GlassConfirmStrip), findsOneWidget);
        await tester.tap(confirmInStrip());
        await tester.pumpAndSettle();
        // 精确删除被点格, 另一孪生保留。
        expect(removed, [0]);
        expect(batches, isEmpty);
        expect(find.byType(GlassConfirmStrip), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'batch with twins shows the frozen count and removes both',
      (tester) async {
        final a = PlaylistItem(path: 'a.mp4');
        final b = PlaylistItem(path: 'b.mp4');
        final removed = <int>[];
        final batches = <Set<int>>[];
        final entries = ValueNotifier([a, a, b]);
        await pumpPanel(
          tester,
          entries: entries,
          removed: removed,
          batches: batches,
        );
        // 进入批量模式 (首格默认选中), 再补选第二格孪生。
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).first)
            .onStartBatchSelect
            ?.call();
        await tester.pumpAndSettle();
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).at(1))
            .onToggleSelect
            ?.call();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Confirm deletion'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassConfirmStrip), findsOneWidget);
        // 文案计数 == 冻结目标数 2 — 精确匹配批量文案, 避开头部"2 selected"。
        expect(
          find.textContaining('2 video entries will be removed'),
          findsOneWidget,
        );
        await tester.tap(confirmInStrip());
        await tester.pumpAndSettle();
        expect(batches, [
          {0, 1},
        ]);
        expect(removed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mixed twins and vanished target resolves frozen positions only',
      (tester) async {
        final a = PlaylistItem(path: 'a.mp4');
        final b = PlaylistItem(path: 'b.mp4');
        final removed = <int>[];
        final batches = <Set<int>>[];
        final entries = ValueNotifier([a, a, b]);
        await pumpPanel(
          tester,
          entries: entries,
          removed: removed,
          batches: batches,
        );
        // 进入批量模式后全选 {0, 1, 2}: 两条 a 孪生 + b。
        tester
            .widget<PlaylistTile>(find.byType(PlaylistTile).first)
            .onStartBatchSelect
            ?.call();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Select all'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Confirm deletion'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassConfirmStrip), findsOneWidget);
        // 确认期间 b 消失 — a 孪生各自按冻结位命中, b 跳过, 不抛异常。
        entries.value = [a, a];
        await tester.pump();
        await tester.tap(confirmInStrip());
        await tester.pumpAndSettle();
        expect(batches, [
          {0, 1},
        ]);
        expect(removed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
