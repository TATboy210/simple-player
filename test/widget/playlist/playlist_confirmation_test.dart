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
}
