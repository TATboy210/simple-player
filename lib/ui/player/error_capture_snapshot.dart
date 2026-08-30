import 'package:flutter/foundation.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporting_dependencies.dart';

/// D-11 本地有界错误快照 —— 徽标轮览数据源（呈现层私有，零 kernel 改动）。
///
/// 数据源是 reporter **既有**的 effects 扩展点（Phase 2 设计的唯一副作用
/// 缝，`ErrorReporterImpl.init(effects: ...)` 挂入）：组合根把 [record] 加进
/// effects，宿主经 [reports] 监听变化。之所以不走 presentation 通知维护
/// 快照：presentation 只发布 FIFO 队首（`_publishSafely` 的 `current` 是
/// `_queue.first`），后入队报告在成为队首前对呈现层不可见 —— D-01「新错误
/// 替换卡片内容」与徽标「已捕获错误数」在该缝上不可实现（03-03 执行期被
/// 测试证伪后的 fallback；依据 research Open Question 3 的精神：不新增
/// kernel 只读 API，改用既有 effect 缝）。
///
/// 有界性：上界 [maxLength]（20），超出挤掉最旧 —— 与 kernel 队列 5 条 /
/// 去重 10s 同一有界思想，回看场景放宽；完整证据仍由 error.log 落盘兜底。
/// 线程契约：effect 在 reporter 的同步 fan-out 内被调用（UI isolate），
/// ValueNotifier 赋值即通知，无锁。
final class ErrorCaptureSnapshot {
  ErrorCaptureSnapshot._();
  static final ErrorCaptureSnapshot I = ErrorCaptureSnapshot._();

  /// 快照上界命名常量 —— 超出挤掉最旧（最旧优先出队）。
  static const int maxLength = 20;

  final ValueNotifier<List<ErrorReport>> _reports =
      ValueNotifier<List<ErrorReport>>(const <ErrorReport>[]);

  /// 只读快照列表（最新在尾）；宿主监听此 notifier 触发重渲染。
  ValueListenable<List<ErrorReport>> get reports => _reports;

  /// Effect 缝签名（[ErrorReportEffect]）：每次接纳（新报告或同窗合并）
  /// 由 reporter 调用。D-02 分层：warning 不上卡片，直接跳过不进快照。
  ///
  /// 身份语义：以 [ErrorReport.eventId] 为身份 —— 合并只改 occurrenceCount
  /// 不改 eventId，故合并报告在快照中**原地替换**（保持捕获顺序）。
  void record(ErrorReport report, ReportAcceptance acceptance) {
    if (report.severity == ErrorSeverity.warning) return;
    final list = _reports.value;
    final existingIndex = list.indexWhere((r) => r.eventId == report.eventId);
    if (existingIndex >= 0) {
      // 合并（occurrenceCount 增长）：原地替换，不产生重复条目。
      final next = List<ErrorReport>.of(list)..[existingIndex] = report;
      _reports.value = next;
      return;
    }
    final next = List<ErrorReport>.of(list)..add(report);
    while (next.length > maxLength) {
      next.removeAt(0); // 挤掉最旧
    }
    _reports.value = next;
  }

  /// 手动关闭后移除真实队首（宿主 `_onClose` 调用；不在 effect 内做 ——
  /// dismiss 是消费语义，只由显式关闭触发）。
  void removeById(String eventId) {
    final list = _reports.value;
    final existingIndex = list.indexWhere((r) => r.eventId == eventId);
    if (existingIndex < 0) return;
    final next = List<ErrorReport>.of(list)..removeAt(existingIndex);
    _reports.value = next;
  }

  /// 测试隔离：清空快照（配合 `ErrorReporterImpl.resetForTesting` 使用）。
  @visibleForTesting
  void resetForTesting() {
    _reports.value = const <ErrorReport>[];
  }
}
