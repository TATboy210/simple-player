import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/resize_frame_metrics.dart';

void main() {
  setUpAll(() {
    // ResizeFrameMetrics._logSummary 走 KernelLogger.I (未注入 logger 时),
    // 必须 init 否则 StateError. 测试默认 kDebugMode=true → _enabled=true,
    // 会真实注册 isResizing listener + SchedulerBinding timings 回调.
    TestWidgetsFlutterBinding.ensureInitialized();
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('ResizeFrameMetrics', () {
    test('construct + dispose does not throw', () {
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(isResizing: vn);
      m.dispose();
      vn.dispose();
    });

    test('isResizing true→false cycle does not throw (no frames)', () {
      // 无真实帧 → _endSession 走 "no frames captured" debug 分支.
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(isResizing: vn);
      vn.value = true;
      vn.value = false;
      m.dispose();
      vn.dispose();
    });

    test('dispose is idempotent', () {
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(isResizing: vn);
      m.dispose();
      m.dispose();
      vn.dispose();
    });

    test('isResizing toggle after dispose does not throw', () {
      // dispose 后 isResizing 仍可能变化 (WindowService.dispose 顺序) —
      // listener 已移除, 不应触发任何回调.
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(isResizing: vn);
      m.dispose();
      expect(() => vn.value = true, returnsNormally);
      expect(() => vn.value = false, returnsNormally);
      vn.dispose();
    });

    test('repeated isResizing=true is no-op (session already active)', () {
      // 上升沿幂等: 已 active 时再次 true 不重复注册 timings 回调.
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(isResizing: vn);
      vn.value = true;
      vn.value = true; // 应跳过
      vn.value = false;
      m.dispose();
      vn.dispose();
    });

    test('accepts injected logger (no KernelLogger.I access)', () {
      // 注入 logger 时 _logSummary 不走 KernelLogger.I — 隔离性.
      final vn = ValueNotifier<bool>(false);
      final m = ResizeFrameMetrics(
        isResizing: vn,
        logger: KernelLoggerImpl(const NullSink()),
      );
      vn.value = true;
      vn.value = false;
      m.dispose();
      vn.dispose();
    });
  });
}

/// 空日志 sink — 测试用, 吞掉所有输出.
class NullSink implements LogSink {
  const NullSink();
  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
