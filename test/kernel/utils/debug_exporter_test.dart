/// DebugExporter unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the exportAll() JSON serialization and structure.
/// saveToFile() is skipped because it depends on path_provider (platform plugin).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/memory_monitor.dart';
import 'package:simple_player_flutter/kernel/diagnostics/rss_provider.dart';
import 'package:simple_player_flutter/kernel/utils/debug_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
    MemoryMonitor.resetForTesting();
    MemoryMonitor.init(
      MemoryMonitor(
        rssProvider: FakeRssProvider(1024 * 1024), // 1 MB
        clock: const SystemClock(),
        logger: KernelLoggerImpl.I,
      ),
    );
  });

  tearDownAll(() {
    MemoryMonitor.resetForTesting();
  });

  group('DebugExporter', () {
    group('exportAll', () {
      test('returns valid JSON string', () {
        final json = DebugExporter.exportAll();
        expect(() => jsonDecode(json), returnsNormally);
      });

      test('JSON contains memory key', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map.containsKey('memory'), isTrue);
      });

      test('JSON contains probes key', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map.containsKey('probes'), isTrue);
      });

      test('JSON contains exportedAt ISO8601 timestamp', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map.containsKey('exportedAt'), isTrue);
        final timestamp = map['exportedAt'] as String;
        // Verify it's a valid ISO8601 string
        expect(() => DateTime.parse(timestamp), returnsNormally);
      });

      test('JSON contains mode key', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map.containsKey('mode'), isTrue);
        // In test environment, kDebugMode is true
        expect(map['mode'], 'debug');
      });

      test('probes is a Map', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map['probes'], isA<Map<dynamic, dynamic>>());
      });

      test('memory is a Map when MemoryMonitor has data', () {
        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        // MemoryMonitor was initialized with FakeRssProvider(1MB),
        // so snapshot() should return non-null after first tick
        expect(map['memory'], isA<Map<dynamic, dynamic>>());
      });
    });

    group('saveToFile', () {
      test('requires path_provider mock (skipped)', () {
        // saveToFile depends on getApplicationSupportDirectory()
        // which requires platform plugin — cannot test in headless CI
        // This test documents the dependency for future reference.
        expect(DebugExporter.saveToFile, isA<Function>());
      });
    });

    // release 门控配套: MemoryMonitor 未初始化 (release 构建态) 时
    // exportAll 必须安静返回 memory=null, 不得外溢 StateError.
    group('exportAll without MemoryMonitor instance', () {
      test('memory is null and does not throw StateError', () {
        MemoryMonitor.resetForTesting(); // 模拟 release 未初始化态
        expect(MemoryMonitor.isInitialized, isFalse);

        final json = DebugExporter.exportAll();
        final map = jsonDecode(json) as Map<String, dynamic>;
        expect(map['memory'], isNull);

        // 恢复实例, 保护同文件后续可能的测试依赖
        MemoryMonitor.init(
          MemoryMonitor(
            rssProvider: FakeRssProvider(1024 * 1024),
            clock: const SystemClock(),
            logger: KernelLoggerImpl.I,
          ),
        );
      });
    });
  });
}
