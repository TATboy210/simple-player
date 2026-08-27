import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';

import '../../../helpers/fake_kernel_logger.dart';

/// StartupTimeline 单元测试 — 打点/收尾幂等与结构化日志字段契约。
///
/// 经 `KernelLoggerImpl(RecordingLogSink)` 捕获日志；打点间隔为同步零耗时，
/// 只锁「字段名 + 数值域」契约，不锁具体毫秒值（避免 flaky）。
void main() {
  group('StartupTimeline', () {
    test('ready 输出逐阶段差值与 totalMs，阶段字段齐全', () {
      final sink = RecordingLogSink();
      final timeline = StartupTimeline(logger: KernelLoggerImpl(sink));

      timeline.mark(StartupTimeline.phaseInfrastructure);
      timeline.mark(StartupTimeline.phasePlayerInit);
      timeline.ready();

      expect(sink.records, hasLength(1));
      final (level, message, context) = sink.records.single;
      expect(level, LogLevel.info);
      expect(message, 'startup_timeline');
      final ctx = context!;
      expect(
        ctx.keys,
        containsAll(['infrastructureMs', 'playerInitMs', 'totalMs']),
      );
      expect(ctx['infrastructureMs'], isA<int>());
      expect(ctx['playerInitMs'], isA<int>());
      expect(ctx['infrastructureMs'] as int, greaterThanOrEqualTo(0));
      expect(ctx['playerInitMs'] as int, greaterThanOrEqualTo(0));
      expect(ctx['totalMs'], isA<num>());
      expect(
        ctx['totalMs'] as num,
        greaterThanOrEqualTo((ctx['infrastructureMs'] as int).toDouble()),
      );
    });

    test('重复 mark 同一阶段以首点为准', () {
      final sink = RecordingLogSink();
      final timeline = StartupTimeline(logger: KernelLoggerImpl(sink));

      timeline.mark(StartupTimeline.phaseInfrastructure);
      timeline.mark(StartupTimeline.phaseInfrastructure); // 二次标记应被忽略
      timeline.mark(StartupTimeline.phasePlayerInit);
      timeline.ready();

      expect(sink.records, hasLength(1));
      final (_, _, context) = sink.records.single;
      // 两阶段 + total，恰好三个 Ms 字段 — 二次标记未产生新条目。
      expect(context!.keys.where((String k) => k.endsWith('Ms')), hasLength(3));
      expect(context['playerInitMs'], isA<int>());
    });

    test('ready 之后 mark 与 ready 均为 no-op', () {
      final sink = RecordingLogSink();
      final timeline = StartupTimeline(logger: KernelLoggerImpl(sink));

      timeline.mark(StartupTimeline.phaseInfrastructure);
      timeline.ready();
      timeline.mark(StartupTimeline.phasePlayerInit); // 应被忽略
      timeline.ready(); // 应被忽略

      expect(sink.records, hasLength(1));
      final (_, _, context) = sink.records.single;
      // 只有 infrastructure 一段被打点：infrastructureMs + totalMs 共两个。
      expect(context!.keys.where((String k) => k.endsWith('Ms')), hasLength(2));
      expect(context.containsKey('playerInitMs'), isFalse);
    });
  });
}
