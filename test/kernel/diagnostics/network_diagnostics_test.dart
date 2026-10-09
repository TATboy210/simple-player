import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/network_diagnostics.dart';

import '../../helpers/fake_kernel_logger.dart';

/// 本地操作异常替身 — 模拟超时/Socket 等 Exception 族失败（S2 静默分支）.
class _FakeOpException implements Exception {
  @override
  String toString() => '_FakeOpException(op failed)';
}

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

  group('collectNetworkSnapshot — Error 分支防御 (261009-roy S2/F5)', () {
    test('注入同步 Error（非 Exception）— 降级 null 且记诊断日志'
        '（现行为静默吞 → 红）', () async {
      // Arrange — fake 枚举器抛 Error 族; 注入 RecordingLogSink 捕获诊断输出.
      final sink = RecordingLogSink();
      Future<List<({bool isLoopback})>> enumerate() async =>
          throw StateError('network subsystem broken');

      // Act
      final snapshot = await collectNetworkSnapshot(
        enumerate: enumerate,
        logger: KernelLoggerImpl(sink),
      );

      // Assert — 降级语义不变（null, 不炸, 不向上抛）.
      expect(snapshot, isNull);
      // Assert — Error 族降级不得静默（照 dwm_capabilities_probe H1 契约）:
      // 恰一条 error 级诊断日志. 现行为 on Object 全吞零输出 → RED.
      final errorRecords = sink.records
          .where((r) => r.$1 == LogLevel.error)
          .toList();
      expect(errorRecords, hasLength(1), reason: 'Error 族降级不得静默 (F5)');
      expect(errorRecords.single.$2, contains('collectNetworkSnapshot'));
    });

    test('注入 Exception（非 Error）— 保持既有静默降级, 不产生日志', () async {
      // Arrange — Exception 族（超时/Socket 等）走收窄后的 on Exception 分支.
      final sink = RecordingLogSink();
      Future<List<({bool isLoopback})>> enumerate() async =>
          throw _FakeOpException();

      // Act
      final snapshot = await collectNetworkSnapshot(
        enumerate: enumerate,
        logger: KernelLoggerImpl(sink),
      );

      // Assert — 静默降级语义逐字段不变, 且零日志（诊断输出是 Error 族专属）.
      expect(snapshot, isNull);
      expect(sink.records, isEmpty, reason: 'Exception 分支保持既有静默语义');
    });
  });
}
