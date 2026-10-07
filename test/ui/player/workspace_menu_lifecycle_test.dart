import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile.dart';
import 'package:simple_player_flutter/ui/shared/glass_menu.dart';

void main() {
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
