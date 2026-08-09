import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/resize_frame_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResizeFrameMetricsReducer', () {
    test('空样本返回零值摘要', () {
      final summary = ResizeFrameMetricsReducer.reduce(const []);

      expect(summary.sampleCount, 0);
      expect(summary.build, const ResizeTimingSummary.zero());
      expect(summary.raster, const ResizeTimingSummary.zero());
      expect(summary.totalSpan, const ResizeTimingSummary.zero());
      expect(summary.jank60Count, 0);
      expect(summary.jank30Count, 0);
      expect(summary.jank60Ratio, 0);
      expect(summary.jank30Ratio, 0);
    });

    test('nearest-rank 对未排序偶数样本计算 P50 P95 P99', () {
      const samples = [
        ResizeFrameSample(buildUs: 20, rasterUs: 200, totalSpanUs: 2000),
        ResizeFrameSample(buildUs: 10, rasterUs: 100, totalSpanUs: 1000),
      ];

      final summary = ResizeFrameMetricsReducer.reduce(samples);

      expect(summary.build.avgUs, 15);
      expect(summary.build.p50Us, 10);
      expect(summary.build.p95Us, 20);
      expect(summary.build.p99Us, 20);
      expect(summary.build.maxUs, 20);
      expect(summary.raster.p50Us, 100);
      expect(summary.totalSpan.p99Us, 2000);
    });

    test('一百个样本锁定 nearest-rank 百分位索引', () {
      final samples = [
        for (var value = 100; value >= 1; value--)
          ResizeFrameSample(
            buildUs: value,
            rasterUs: value,
            totalSpanUs: value,
          ),
      ];

      final summary = ResizeFrameMetricsReducer.reduce(samples);

      expect(summary.build.p50Us, 50);
      expect(summary.build.p95Us, 95);
      expect(summary.build.p99Us, 99);
    });

    test('帧预算使用严格大于语义并同时累计两个 jank 档位', () {
      const samples = [
        ResizeFrameSample(
          buildUs: 1,
          rasterUs: 1,
          totalSpanUs: ResizeFrameMetricsReducer.frameBudget60Us,
        ),
        ResizeFrameSample(
          buildUs: 1,
          rasterUs: 1,
          totalSpanUs: ResizeFrameMetricsReducer.frameBudget60Us + 1,
        ),
        ResizeFrameSample(
          buildUs: 1,
          rasterUs: 1,
          totalSpanUs: ResizeFrameMetricsReducer.frameBudget30Us,
        ),
        ResizeFrameSample(
          buildUs: 1,
          rasterUs: 1,
          totalSpanUs: ResizeFrameMetricsReducer.frameBudget30Us + 1,
        ),
      ];

      final summary = ResizeFrameMetricsReducer.reduce(samples);

      expect(summary.jank60Count, 3);
      expect(summary.jank30Count, 1);
      expect(summary.jank60Ratio, 0.75);
      expect(summary.jank30Ratio, 0.25);
    });

    test('大整数求和保持整数微秒精度', () {
      const large = 9000000000000;
      const samples = [
        ResizeFrameSample(buildUs: large, rasterUs: large, totalSpanUs: large),
        ResizeFrameSample(
          buildUs: large + 2,
          rasterUs: large + 2,
          totalSpanUs: large + 2,
        ),
      ];

      final summary = ResizeFrameMetricsReducer.reduce(samples);

      expect(summary.build.avgUs, large + 1);
      expect(summary.totalSpan.maxUs, large + 2);
    });
  });

  group('ResizeFrameMetrics 生命周期', () {
    test('禁用时不监听 resize 且不输出日志', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(0);
      final logger = _RecordingLogger();
      final metrics = ResizeFrameMetrics(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        logger: logger,
        enabled: false,
      );

      resizing.value = true;
      resizing.value = false;
      metrics.dispose();

      expect(logger.entries, isEmpty);
      resizing.dispose();
      resizeSessionId.dispose();
    });

    test('在会话开始时冻结并输出 resize sessionId', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(41);
      final logger = _RecordingLogger();
      final metrics = ResizeFrameMetrics(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      // 摘要必须归属已开始的会话，而非结束时 notifier 的最新值。
      resizeSessionId.value = 42;
      resizing.value = false;

      expect(logger.entries, hasLength(1));
      expect(logger.entries.single.message, 'resize_frame_metrics');
      expect(
        logger.entries.single.context?.keys.toSet(),
        ResizeFrameSummary.contextKeys,
      );
      expect(logger.entries.single.context?['sessionId'], 41);
      expect(logger.entries.single.context?['sampleCount'], 0);

      metrics.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
    });

    test('日志 sink 重入开启下一会话时不清空新会话样本', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(51);
      ResizeFrameMetrics? metrics;
      final logger = _ReentrantMetricsLogger(
        onFirstEntry: () {
          resizeSessionId.value = 52;
          resizing.value = true;
          // 第二会话必须在旧摘要 logger 尚未返回时已有样本，才能验证旧收尾
          // 不会误清空新会话的采集缓冲区。
          metrics?.recordSamplesForTesting(const [
            ResizeFrameSample(buildUs: 111, rasterUs: 222, totalSpanUs: 444),
          ]);
        },
      );
      metrics = ResizeFrameMetrics(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      resizing.value = false;
      resizing.value = false;

      expect(logger.entries, hasLength(2));
      expect(logger.entries[0].context?['sessionId'], 51);
      expect(logger.entries[1].context?['sessionId'], 52);
      expect(logger.entries[1].context?['sampleCount'], 1);
      expect(logger.entries[1].context?['buildAvgUs'], 111);
      expect(logger.entries[1].context?['rasterAvgUs'], 222);
      expect(logger.entries[1].context?['totalAvgUs'], 444);

      metrics.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
    });

    test('初始正在 resize 时同步开启会话并输出空摘要 schema', () {
      final resizing = ValueNotifier<bool>(true);
      final resizeSessionId = ValueNotifier<int>(7);
      final logger = _RecordingLogger();
      final metrics = ResizeFrameMetrics(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        logger: logger,
        enabled: true,
      );

      resizing.value = false;

      expect(logger.entries, hasLength(1));
      expect(logger.entries.single.message, 'resize_frame_metrics');
      expect(
        logger.entries.single.context?.keys.toSet(),
        ResizeFrameSummary.contextKeys,
      );
      expect(logger.entries.single.context?['sessionId'], 7);
      expect(logger.entries.single.context?['sampleCount'], 0);

      metrics.dispose();
      metrics.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
    });
  });
}

final class _LogEntry {
  const _LogEntry(this.message, this.context);

  final String message;
  final Map<String, Object?>? context;
}

class _RecordingLogger extends KernelLogger {
  final List<_LogEntry> entries = [];

  @override
  void trace(String message, {Map<String, Object?>? context}) {}

  @override
  void debug(String message, {Map<String, Object?>? context}) {
    entries.add(_LogEntry(message, context));
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    entries.add(_LogEntry(message, context));
  }

  @override
  void warn(String message, {Map<String, Object?>? context}) {}

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

/// 模拟日志写出期间同步启动下一段 resize 的可重入 sink。
final class _ReentrantMetricsLogger extends _RecordingLogger {
  _ReentrantMetricsLogger({required this.onFirstEntry});

  final void Function() onFirstEntry;
  bool _hasReentered = false;

  @override
  void info(String message, {Map<String, Object?>? context}) {
    super.info(message, context: context);
    if (_hasReentered) return;
    _hasReentered = true;
    // 旧摘要尚在写出时启动新会话，复现同步 sink 的重入边界。
    onFirstEntry();
  }
}
