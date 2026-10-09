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

  // ── T-261009-fj6-01 缓解：注册期同 id 冲突检测（debug assert）──
  group('registry register/unregister contract', () {
    WorkspaceFocusRegistry buildRegistry() {
      final workspace = PanelWorkspaceController();
      final player = FocusNode();
      addTearDown(workspace.dispose);
      addTearDown(player.dispose);
      return WorkspaceFocusRegistry(controller: workspace, player: player);
    }

    test('registerTask asserts same id bound to a different scope', () {
      final registry = buildRegistry();
      final first = FocusScopeNode();
      final second = FocusScopeNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      registry.registerTask('settings', first);
      expect(
        () => registry.registerTask('settings', second),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('settings'),
          ),
        ),
      );
      // 冲突注册不得静默顶掉既有条目（debug 下 assert 先于赋值抛出）。
      expect(identical(registry.tasks['settings'], first), isTrue);
    });

    test('registerTrigger asserts same id bound to a different node', () {
      final registry = buildRegistry();
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      registry.registerTrigger('settings', first);
      expect(
        () => registry.registerTrigger('settings', second),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('settings'),
          ),
        ),
      );
      expect(identical(registry.triggers['settings'], first), isTrue);
    });

    test('identical instance rebinds are idempotent no-ops', () {
      final registry = buildRegistry();
      final scope = FocusScopeNode();
      final node = FocusNode();
      addTearDown(scope.dispose);
      addTearDown(node.dispose);
      registry.registerTask('settings', scope);
      registry.registerTask('settings', scope);
      registry.registerTrigger('settings', node);
      registry.registerTrigger('settings', node);
      expect(identical(registry.tasks['settings'], scope), isTrue);
      expect(identical(registry.triggers['settings'], node), isTrue);
    });

    test('different ids register independently', () {
      final registry = buildRegistry();
      final scopeA = FocusScopeNode();
      final scopeB = FocusScopeNode();
      final nodeA = FocusNode();
      final nodeB = FocusNode();
      addTearDown(scopeA.dispose);
      addTearDown(scopeB.dispose);
      addTearDown(nodeA.dispose);
      addTearDown(nodeB.dispose);
      registry.registerTask('settings', scopeA);
      registry.registerTask('left', scopeB);
      registry.registerTrigger('settings', nodeA);
      registry.registerTrigger('center', nodeB);
      expect(identical(registry.tasks['settings'], scopeA), isTrue);
      expect(identical(registry.tasks['left'], scopeB), isTrue);
      expect(identical(registry.triggers['settings'], nodeA), isTrue);
      expect(identical(registry.triggers['center'], nodeB), isTrue);
    });

    test('unregisterTask only removes the identical instance', () {
      final registry = buildRegistry();
      final scope = FocusScopeNode();
      final stranger = FocusScopeNode();
      addTearDown(scope.dispose);
      addTearDown(stranger.dispose);
      registry.registerTask('settings', scope);
      // 不同实例 → 条目原样保留（防误删后来者的注册）。
      registry.unregisterTask('settings', stranger);
      expect(identical(registry.tasks['settings'], scope), isTrue);
      // identical 实例 → 移除。
      registry.unregisterTask('settings', scope);
      expect(registry.tasks['settings'], isNull);
    });

    test('unregisterTrigger only removes the identical instance', () {
      final registry = buildRegistry();
      final node = FocusNode();
      final stranger = FocusNode();
      addTearDown(node.dispose);
      addTearDown(stranger.dispose);
      registry.registerTrigger('settings', node);
      registry.unregisterTrigger('settings', stranger);
      expect(identical(registry.triggers['settings'], node), isTrue);
      registry.unregisterTrigger('settings', node);
      expect(registry.triggers['settings'], isNull);
    });
  });
}
