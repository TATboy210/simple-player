import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_session.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_host.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/right_button_group.dart';
import 'package:simple_player_flutter/ui/player/workspace_focus_scope.dart';

void main() {
  testWidgets('hidden position ticker stops and re-show reaches current rect', (
    tester,
  ) async {
    final workspace = PanelWorkspaceController()..toggle('settings');
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PanelWorkspaceHost(
          controller: workspace,
          tasks: [
            for (final id in ['settings', 'second', 'third'])
              WorkspaceTask(id: id, builder: (_, _, _) => Text(id)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final settingsPosition = find.ancestor(
      of: find.text('settings', skipOffstage: false),
      matching: find.byType(AnimatedPositioned),
    );
    final originalState = tester.state(settingsPosition);
    workspace.toggle('second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    workspace.toggle('third');
    await tester.pump();
    final renderedPosition = find.descendant(
      of: settingsPosition,
      matching: find.byType(Positioned),
      skipOffstage: false,
    );
    final before = tester.widget<Positioned>(renderedPosition).left;
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<Positioned>(renderedPosition).left,
      before,
      reason: 'Hidden position animation must not tick',
    );
    workspace.toggle('settings');
    await tester.pumpAndSettle();
    expect(identical(tester.state(settingsPosition), originalState), isTrue);
    final target = tester.widget<AnimatedPositioned>(settingsPosition);
    final actual = tester.getRect(find.text('settings'));
    expect(actual.left, closeTo(target.left ?? 0, 0.001));
    expect(
      tester.widget<Positioned>(renderedPosition).left,
      closeTo(target.left ?? 0, 0.001),
    );
    expect(tester.takeException(), isNull);
  });
  test('session publishes only exact navigation and scroll changes', () {
    final session = SettingsPanelSession();
    addTearDown(session.dispose);
    var notifications = 0;
    session.addListener(() => notifications++);
    final initial = session.value;
    session.navigate('about', false);
    expect(notifications, 0);
    expect(identical(initial, session.value), isTrue);
    session.navigate('audio', true);
    session.navigate('audio', true);
    expect(notifications, 1);
    session.recordScroll('audio', 0);
    expect(notifications, 2, reason: 'First zero offset records a missing key');
    final recorded = session.value;
    session.recordScroll('audio', 0);
    expect(identical(recorded, session.value), isTrue);
    session.recordScroll('audio', 0.000001);
    expect(notifications, 3, reason: 'No epsilon or scroll fidelity loss');
    expect(recorded.scrollOffsets['audio'], 0);
    expect(session.value.scrollOffsets['audio'], 0.000001);
  });

  testWidgets('trigger rebinds registry and preserves another trigger owner', (
    tester,
  ) async {
    final workspace = PanelWorkspaceController();
    final player = FocusNode();
    final replacement = FocusNode();
    addTearDown(workspace.dispose);
    addTearDown(player.dispose);
    addTearDown(replacement.dispose);
    final r1 = WorkspaceFocusRegistry(controller: workspace, player: player);
    final r2 = WorkspaceFocusRegistry(controller: workspace, player: player);
    Widget subject(WorkspaceFocusRegistry registry) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WorkspaceFocusScope(
        registry: registry,
        child: RightButtonGroup(actions: PlayerActions(onOpenSettings: () {})),
      ),
    );
    await tester.pumpWidget(subject(r1));
    final original = r1.triggers['settings'];
    expect(original, isNotNull);
    await tester.pumpWidget(subject(r2));
    expect(r1.triggers, isEmpty);
    expect(identical(r2.triggers['settings'], original), isTrue);
    r2.triggers['settings'] = replacement;
    await tester.pumpWidget(subject(r1));
    expect(identical(r2.triggers['settings'], replacement), isTrue);
    expect(identical(r1.triggers['settings'], original), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(r1.triggers, isEmpty);
    expect(identical(r2.triggers['settings'], replacement), isTrue);
  });

  testWidgets('host keeps subscriptions on resize and rebinds new sources', (
    tester,
  ) async {
    final first = _CountingWorkspace()..toggle('settings');
    final second = _CountingWorkspace()..toggle('settings');
    final resize1 = _CountingResize();
    final resize2 = _CountingResize();
    for (final source in [first, second, resize1, resize2]) {
      addTearDown(source.dispose);
    }
    Widget subject(
      double width,
      PanelWorkspaceController controller,
      ValueNotifier<bool> signal,
    ) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          height: 400,
          child: PanelWorkspaceHost(
            controller: controller,
            resizeSignal: signal,
            tasks: [
              WorkspaceTask(
                id: 'settings',
                builder: (_, _, _) => const Text('settings'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(subject(700, first, resize1));
    final initialAdds = first.adds;
    final initialResizeAdds = resize1.adds;
    final initialWidth = tester
        .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
        .width;
    await tester.pumpWidget(subject(600, first, resize1));
    expect(first.adds, initialAdds);
    expect(first.removes, 0);
    expect(resize1.adds, initialResizeAdds);
    expect(resize1.removes, 0);
    expect(
      tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).width,
      isNot(initialWidth),
    );
    await tester.pumpWidget(subject(600, second, resize2));
    expect(first.removes, initialAdds);
    expect(resize1.removes, initialResizeAdds);
    expect(second.adds, 1);
    expect(resize2.adds, 1);
    resize2.value = true;
    await tester.pump();
    expect(
      tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .duration,
      Duration.zero,
    );
    await tester.pumpWidget(const SizedBox());
    expect(second.removes, second.adds);
    expect(resize2.removes, resize2.adds);
  });
}

/// Counts actual observer operations rather than inferring rebuild costs.
class _CountingWorkspace extends PanelWorkspaceController {
  int adds = 0;
  int removes = 0;
  @override
  void addListener(VoidCallback listener) {
    adds++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removes++;
    super.removeListener(listener);
  }
}

/// Resize source instrumentation leaves notification semantics unchanged.
class _CountingResize extends ValueNotifier<bool> {
  _CountingResize() : super(false);
  int adds = 0;
  int removes = 0;
  @override
  void addListener(VoidCallback listener) {
    adds++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removes++;
    super.removeListener(listener);
  }
}
