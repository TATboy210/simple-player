import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

/// 录制型日志 sink — 单方法实现 [LogSink]，收集每条日志供测试断言。
///
/// 经 `KernelLoggerImpl(RecordingLogSink())` 注入诊断类，避免依赖
/// [KernelLoggerImpl.init] 全局态。
final class RecordingLogSink implements LogSink {
  /// 已收到的日志 — (level, message, context) 三元组列表。
  final List<(LogLevel, String, Map<String, Object?>?)> records = [];

  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    records.add((level, msg, context));
  }
}
