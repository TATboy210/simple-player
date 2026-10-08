import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface_visibility.dart';
import 'package:simple_player_flutter/ui/shared/secondary_surface.dart';

void main() {
  for (final action in ['Play', 'Remove', 'Batch delete']) {
    testWidgets('actual tile typed $action preserves captured entry action', (
      tester,
    ) async {
      final menus = WorkspaceMenuSession();
      final visible = ValueNotifier(true);
      final calls = <String>[];
      addTearDown(menus.dispose);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {},
            child: SecondarySurfaceVisibility(
              visibility: visible,
              child: Scaffold(
                body: SizedBox(
                  width: 280,
                  child: PlaylistTile(
                    item: PlaylistItem(path: 'D:/missing/captured.mp4'),
                    isCurrent: false,
                    isResumeAnchor: false,
                    onPlay: () => calls.add('Play'),
                    onResume: () => calls.add('Resume'),
                    onRemove: () => calls.add('Remove'),
                    onStartBatchSelect: () => calls.add('Batch delete'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final tile = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byType(PlaylistTile),
              matching: find.byType(InkWell),
            )
            .first,
      );
      tile.onSecondaryTapUp?.call(
        TapUpDetails(
          globalPosition: const Offset(25, 25),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      expect(menus.isOwnedMenuTopmost, isTrue);
      menus.mediaChanged('unrelated-playing-path');
      expect(menus.isOwnedMenuTopmost, isTrue);
      expect(find.text('Open File Location'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SecondarySurface),
          matching: find.text(action),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, [action]);
      expect(tile.focusNode?.hasPrimaryFocus, isTrue);
      tile.onSecondaryTapUp?.call(
        TapUpDetails(
          globalPosition: const Offset(25, 25),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      visible.value = false;
      expect(menus.currentToken, isNull, reason: 'live hide is synchronous');
      await tester.pumpAndSettle();
      expect(find.byType(SecondarySurface), findsNothing);
      expect(calls, [action]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final remove in [false, true]) {
    testWidgets(
      'entry menu cancels safely during ${remove ? 'disposal' : 'path replacement'}',
      (tester) async {
        final menus = WorkspaceMenuSession();
        addTearDown(menus.dispose);
        final path = ValueNotifier('D:/missing/a.mp4');
        addTearDown(path.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkspaceMenuScope(
              session: menus,
              onEscape: () {},
              child: Scaffold(
                body: ValueListenableBuilder<String>(
                  valueListenable: path,
                  builder: (_, value, _) => value.isEmpty
                      ? const SizedBox.shrink()
                      : SizedBox(
                          width: 280,
                          child: PlaylistTile(
                            item: PlaylistItem(path: value),
                            isCurrent: false,
                            isResumeAnchor: false,
                            onPlay: () {},
                            onResume: () {},
                            onRemove: () {},
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final tile = tester.widget<InkWell>(
          find
              .descendant(
                of: find.byType(PlaylistTile),
                matching: find.byType(InkWell),
              )
              .first,
        );
        tile.onSecondaryTapUp?.call(
          TapUpDetails(
            globalPosition: const Offset(20, 20),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pump();
        expect(
          find.byType(GlassMenuItem),
          findsNothing,
        ); // items are values, not widgets
        expect(menus.value, isTrue);
        menus.mediaChanged('playing-b');
        expect(
          menus.value,
          isTrue,
        ); // entry identity is unrelated to active playback
        path.value = remove ? '' : 'D:/missing/b.mp4';
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(menus.value, isFalse);
        expect(find.text('Open file location'), findsNothing);
      },
    );
  }

  for (final replacePath in [true, false]) {
    testWidgets(
      'actual tile ${replacePath ? 'path replacement rejects' : 'same owner outside cancel restores'} trigger focus',
      (tester) async {
        final menus = WorkspaceMenuSession();
        final path = ValueNotifier('D:/missing/a.mp4');
        final unrelated = FocusNode(debugLabel: 'unrelated-entry-focus');
        final calls = <String>[];
        addTearDown(menus.dispose);
        addTearDown(path.dispose);
        addTearDown(unrelated.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkspaceMenuScope(
              session: menus,
              onEscape: () {},
              child: Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      focusNode: unrelated,
                      onPressed: () {},
                      child: const Text('Unrelated'),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: path,
                      builder: (_, value, _) => SizedBox(
                        width: 280,
                        child: PlaylistTile(
                          item: PlaylistItem(path: value),
                          isCurrent: false,
                          isResumeAnchor: false,
                          onPlay: () => calls.add('play-$value'),
                          onResume: () => calls.add('resume-$value'),
                          onRemove: () => calls.add('remove-$value'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final state = tester.state(find.byType(PlaylistTile));
        final tile = tester.widget<InkWell>(
          find
              .descendant(
                of: find.byType(PlaylistTile),
                matching: find.byType(InkWell),
              )
              .first,
        );
        tile.onSecondaryTapUp?.call(
          TapUpDetails(
            globalPosition: const Offset(25, 100),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pumpAndSettle();
        final oldAction = tester.widget<InkWell>(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(SecondarySurface),
                  matching: find.text('Remove'),
                ),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(menus.isOwnedMenuTopmost, isTrue);
        menus.mediaChanged('unrelated-playback-media');
        expect(menus.isOwnedMenuTopmost, isTrue);
        unrelated.requestFocus();
        await tester.pump();
        expect(unrelated.hasPrimaryFocus, isTrue);
        if (replacePath) {
          path.value = 'D:/missing/b.mp4';
        } else {
          // Real barrier dismissal, not a weaker blanket restore suppression.
          await tester.tapAt(const Offset(700, 500));
        }
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(PlaylistTile)), same(state));
        expect(menus.currentToken, isNull);
        expect(find.byType(SecondarySurface), findsNothing);
        expect(unrelated.hasPrimaryFocus, replacePath);
        expect(tile.focusNode?.hasPrimaryFocus, !replacePath);
        // A retained old row callback must not act on A or its reused B State.
        oldAction.onTap?.call();
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('build cancellation cannot clear replacement session', (
    tester,
  ) async {
    final menus = WorkspaceMenuSession();
    final rebuild = ValueNotifier(false);
    addTearDown(rebuild.dispose);
    var oldClosed = false;
    var newClosed = false;
    final old = menus.open(
      owner: 'old',
      cancel: () => oldClosed = true,
      isCurrent: () => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: rebuild,
          builder: (_, replace, _) {
            if (replace) {
              menus.cancelOwner('old');
              menus.open(
                owner: 'new',
                cancel: () => newClosed = true,
                isCurrent: () => true,
              );
              menus.finish(old);
            }
            return ValueListenableBuilder<bool>(
              valueListenable: menus,
              builder: (_, open, _) => Text('$open'),
            );
          },
        ),
      ),
    );
    rebuild.value = true;
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(oldClosed, isTrue);
    expect(newClosed, isFalse);
    expect(menus.value, isTrue);
    menus.dispose();
    await tester.pump();
    expect(newClosed, isTrue);
  });
}
