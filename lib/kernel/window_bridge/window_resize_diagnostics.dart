/// 窗口缩放撕裂取证开关 — window_frame_kit `ResizeDiagnostics` 的 opt-in 接线.
///
/// Debug/Profile-only opt-in for window_frame_kit's per-gesture resize
/// telemetry. Enable with `--dart-define=RESIZE_DIAG=true`; every finished
/// resize gesture is logged through [KernelLogger] as one info line (frame
/// times, Dart-side surface mismatch and, on Windows with `customFrame`, the
/// native `ResizeSyncStats`: engine waits/timeouts and estimated stale
/// frames DWM composed — the number to judge tearing by).
///
/// 纯观测: 不改任何窗口行为; Release 构建 [ResizeDiagnostics.start] 自身即
/// no-op, 本处再以 [kReleaseMode] 短路, 连监听器都不注册.
library;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:window_frame_kit/window_frame_kit.dart';

import '../diagnostics/kernel_logger.dart';

/// 编译期开关 — `--dart-define=RESIZE_DIAG=true` 时为 true, 默认关闭.
const bool resizeDiagnosticsRequested = bool.fromEnvironment('RESIZE_DIAG');

/// 按需启动缩放取证, 返回已启动的实例 (调用方负责 [ResizeDiagnostics.stop]);
/// 未请求或 Release 构建返回 null.
///
/// [requested] / [releaseMode] 为测试注入 seam, 生产取编译期常量.
/// side effect: 注册 window listener + SchedulerBinding timings 回调.
ResizeDiagnostics? startResizeDiagnosticsIfRequested({
  required KernelLogger logger,
  bool requested = resizeDiagnosticsRequested,
  bool releaseMode = kReleaseMode,
}) {
  if (!requested || releaseMode) return null;
  final diagnostics = ResizeDiagnostics(
    // 每个缩放手势结束各报一次 (window_frame_kit 0.3.0 per-gesture 语义).
    onReport: (report) => logger.i('[ResizeDiag] $report'),
  )..start();
  logger.i('[ResizeDiag] enabled — drag a window edge to collect reports');
  return diagnostics;
}
