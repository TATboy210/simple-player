import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';

void main() {
  test('new center demotes old center and hides old left', () {
    final workspace = PanelWorkspaceController();
    addTearDown(workspace.dispose);
    workspace.toggle('settings');
    expect(workspace.value.center, 'settings');
    workspace.toggle('second');
    expect(workspace.value.center, 'second');
    expect(workspace.value.left, 'settings');
    workspace.toggle('third');
    expect(workspace.value.center, 'third');
    expect(workspace.value.left, 'second');
    expect(workspace.value.isVisible('settings'), isFalse);
  });

  test('toggle visible own identity closes only that task', () {
    final workspace = PanelWorkspaceController();
    addTearDown(workspace.dispose);
    workspace.toggle('settings');
    workspace.toggle('second');
    workspace.toggle('settings');
    expect(workspace.value.left, isNull);
    expect(workspace.value.center, 'second');
    workspace.toggle('second');
    expect(workspace.value.hasTasks, isFalse);
  });

  test('promotion swaps roles and closing center promotes left', () {
    final workspace = PanelWorkspaceController();
    addTearDown(workspace.dispose);
    workspace.toggle('settings');
    workspace.toggle('second');
    workspace.promote('settings');
    expect(workspace.value.center, 'settings');
    expect(workspace.value.left, 'second');
    workspace.close('settings');
    expect(workspace.value.center, 'second');
    expect(workspace.value.left, isNull);
    workspace.promote('hidden');
    expect(workspace.value.center, 'second');
  });

  test('blank closes one center at a time and no tasks is a no-op', () {
    final workspace = PanelWorkspaceController();
    addTearDown(workspace.dispose);
    expect(workspace.closeCenter(), isFalse);
    workspace.toggle('settings');
    workspace.toggle('second');
    expect(workspace.closeCenter(), isTrue);
    expect(workspace.value.center, 'settings');
    expect(workspace.closeCenter(), isTrue);
    expect(workspace.closeCenter(), isFalse);
  });
}
