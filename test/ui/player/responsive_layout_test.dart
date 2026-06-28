import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import '../../helpers/fake_engine.dart';

Widget _wrapWithApp(Widget child, {double width = 800, double height = 600}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  );
}

void main() {
  late FakeEngine engine;
  late Playlist playlist;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
  });

  tearDown(() {
    engine.dispose();
  });

  group('ControlBar width consistency', () {
    testWidgets('ultra-compact (<=360) hides left/right button groups',
        (tester) async {
      await tester.pumpWidget(_wrapWithApp(
        ControlBar(engine: engine, actions: const PlayerActions()),
        width: 360,
        height: 200,
      ));
      await tester.pump();

      // Ultra-compact: play mode button (left group) hidden
      expect(find.byIcon(Icons.repeat), findsNothing);
    });

    testWidgets('compact (360-500) shows center group only', (tester) async {
      await tester.pumpWidget(_wrapWithApp(
        ControlBar(engine: engine, actions: const PlayerActions()),
        width: 480,
        height: 200,
      ));
      await tester.pump();

      // Compact: CenterGroup visible, no left/right groups
      expect(find.byType(CenterGroup), findsOneWidget);
    });

    testWidgets('wide (>=500) shows all three groups', (tester) async {
      await tester.pumpWidget(_wrapWithApp(
        ControlBar(engine: engine, actions: const PlayerActions()),
        width: 800,
        height: 200,
      ));
      await tester.pump();

      // Wide: CenterGroup visible
      expect(find.byType(CenterGroup), findsOneWidget);
      // Play mode button (left group) visible
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });
  });

  group('PlaylistPanel responsive sizing', () {
    testWidgets('uses narrow size when availableWidth < 600', (tester) async {
      await tester.pumpWidget(_wrapWithApp(
        PlaylistPanel(
          playlist: playlist,
          visible: true,
          onClose: () {},
          onSelectIndex: (_) {},
          onRemoveIndex: (_) {},
          availableWidth: 500,
        ),
        width: 500,
        height: 600,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Panel should use narrow dimensions
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(PlaylistPanel),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == Tokens.playlistPanelWidthNarrow,
          ),
        ),
      );
      expect(sizedBox.width, Tokens.playlistPanelWidthNarrow);
      expect(sizedBox.height, Tokens.playlistPanelHeightNarrow);
    });

    testWidgets('uses normal size when availableWidth >= 600', (tester) async {
      await tester.pumpWidget(_wrapWithApp(
        PlaylistPanel(
          playlist: playlist,
          visible: true,
          onClose: () {},
          onSelectIndex: (_) {},
          onRemoveIndex: (_) {},
          availableWidth: 800,
        ),
        width: 800,
        height: 600,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(PlaylistPanel),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == Tokens.playlistPanelWidth,
          ),
        ),
      );
      expect(sizedBox.width, Tokens.playlistPanelWidth);
      expect(sizedBox.height, Tokens.playlistPanelHeight);
    });
  });

  group('Tokens responsive constants', () {
    test('breakpointWide is 600', () {
      expect(Tokens.breakpointWide, 600);
    });

    test('breakpointUltraCompact is 360', () {
      expect(Tokens.breakpointUltraCompact, 360);
    });

    test('narrow playlist dimensions are smaller than normal', () {
      expect(Tokens.playlistPanelWidthNarrow, lessThan(Tokens.playlistPanelWidth));
      expect(Tokens.playlistPanelHeightNarrow, lessThan(Tokens.playlistPanelHeight));
    });

    test('compactBreakpoint unchanged at 500', () {
      expect(Tokens.compactBreakpoint, 500);
    });
  });
}
