import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/network_diagnostics.dart';

void main() {
  group('collectNetworkSnapshot (B5/9)', () {
    test('2 条接口 (1 loopback + 1 非 loopback) → '
        '快照 (interfaceCount: 2, hasNonLoopback: true)', () async {
      // Arrange — fake 枚举器返回 1 loopback + 1 非 loopback, 不依赖真实网络.
      Future<List<({bool isLoopback})>> enumerate() async =>
          <({bool isLoopback})>[(isLoopback: true), (isLoopback: false)];

      // Act
      final snapshot = await collectNetworkSnapshot(enumerate: enumerate);

      // Assert
      expect(snapshot, isNotNull);
      expect(snapshot!.interfaceCount, 2);
      expect(snapshot.hasNonLoopback, isTrue);
    });

    test('0 条接口 → 快照 (interfaceCount: 0, hasNonLoopback: false)', () async {
      // Arrange
      Future<List<({bool isLoopback})>> enumerate() async =>
          <({bool isLoopback})>[];

      // Act
      final snapshot = await collectNetworkSnapshot(enumerate: enumerate);

      // Assert
      expect(snapshot, isNotNull);
      expect(snapshot!.interfaceCount, 0);
      expect(snapshot.hasNonLoopback, isFalse);
    });

    test(
      '1 条纯 loopback → 快照 (interfaceCount: 1, hasNonLoopback: false)',
      () async {
        // Arrange
        Future<List<({bool isLoopback})>> enumerate() async =>
            <({bool isLoopback})>[(isLoopback: true)];

        // Act
        final snapshot = await collectNetworkSnapshot(enumerate: enumerate);

        // Assert
        expect(snapshot, isNotNull);
        expect(snapshot!.interfaceCount, 1);
        expect(snapshot.hasNonLoopback, isFalse);
      },
    );

    test('枚举器抛异常 → 返回 null (静默降级, 不炸)', () async {
      // Arrange — fake 枚举器抛异常, 模拟 NetworkInterface.list 失败.
      Future<List<({bool isLoopback})>> enumerate() async =>
          throw StateError('network subsystem down');

      // Act
      final snapshot = await collectNetworkSnapshot(enumerate: enumerate);

      // Assert — 静默降级为 null, 不向上抛.
      expect(snapshot, isNull);
    });
  });
}
