import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';

/// Deliberately equal labels must not mean equal owner lifetimes.
class _Owner {
  @override
  bool operator ==(Object other) => other is _Owner;
  @override
  int get hashCode => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('equal-looking distinct owners cannot cancel another menu', () {
    final menus = WorkspaceMenuSession();
    addTearDown(menus.dispose);
    final first = _Owner();
    final second = _Owner();
    var closed = false;
    menus.open(
      owner: first,
      cancel: () => closed = true,
      isCurrent: () => true,
    );
    menus.cancelOwner(second);
    expect(closed, isFalse);
    expect(menus.value, isTrue);
    menus.cancelOwner(first);
    expect(closed, isTrue);
  });
}
