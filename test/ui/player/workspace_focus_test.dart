import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/workspace_focus_scope.dart';

void main() {
  for (final cause in WorkspaceCloseCause.values) {
    testWidgets('$cause closes center and focuses valid target', (
      tester,
    ) async {
      final workspace = PanelWorkspaceController()
        ..toggle('left')
        ..toggle('center');
      final player = FocusNode();
      final trigger = FocusNode();
      final scope = FocusScopeNode();
      final field = FocusNode();
      final focus = WorkspaceFocusRegistry(
        controller: workspace,
        player: player,
      );
      focus.tasks['left'] = scope;
      focus.triggers['center'] = trigger;
      addTearDown(workspace.dispose);
      addTearDown(player.dispose);
      addTearDown(trigger.dispose);
      addTearDown(scope.dispose);
      addTearDown(field.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Focus(focusNode: player, child: const Text('player')),
              Focus(focusNode: trigger, child: const Text('trigger')),
              FocusScope(
                node: scope,
                child: Focus(focusNode: field, child: const Text('task field')),
              ),
            ],
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);
      focus.close('center', cause);
      await tester.pump();
      await tester.idle();
      await tester.pump();
      expect(
        cause == WorkspaceCloseCause.blank
            ? player.hasPrimaryFocus
            : field.hasPrimaryFocus,
        isTrue,
        reason:
            'primary=${FocusManager.instance.primaryFocus}; player=${player.context} can=${player.canRequestFocus}',
      );
      focus.close('left', WorkspaceCloseCause.header);
      await tester.pump();
      await tester.idle();
      await tester.pump();
      // No registered left trigger, so fallback is attached player.
      expect(player.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('header returns actual settings trigger when no promoted task', (
    tester,
  ) async {
    final workspace = PanelWorkspaceController()..toggle('settings');
    final player = FocusNode();
    final trigger = FocusNode();
    final registry = WorkspaceFocusRegistry(
      controller: workspace,
      player: player,
    );
    registry.triggers['settings'] = trigger;
    addTearDown(workspace.dispose);
    addTearDown(player.dispose);
    addTearDown(trigger.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focus(focusNode: player, child: const Text('player')),
            TextButton(
              focusNode: trigger,
              onPressed: () =>
                  registry.close('settings', WorkspaceCloseCause.header),
              child: const Text('close'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('close'));
    await tester.pump();
    await tester.pump();
    expect(trigger.hasPrimaryFocus, isTrue);
  });
}
