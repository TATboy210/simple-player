import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/log.dart';

void main() {
  test('log singleton is initialized', () {
    expect(log, isNotNull);
  });
}
