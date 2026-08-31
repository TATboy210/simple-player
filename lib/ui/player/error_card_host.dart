import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporter.dart';
import '../shared/osd_overlay.dart';
import 'error_capture_snapshot.dart';
import 'error_card.dart';

/// 错误卡片宿主 — ErrorReporter 呈现状态到 UI 的唯一接线人
/// （CARD-05 相位守卫适配器 + CARD-06/D-08/D-12）。
///
/// 六项骨架义务：
/// 1. **监听**：initState 对 `ErrorReporterImpl.I.presentation` addListener；
/// 2. **首帧 flushPresentation**：post-frame 宣布就绪，补呈现挂载前入队的
///    bootstrap/windowInit 窗口错误（D-12）——isReady 门不解除则 `current`
///    恒为 null，卡片永远空白；
/// 3. **相位守卫（CARD-05）**：reporter 在 build 期同步发布（reporter 内部
///    `_reportSafely → _publishSafely`），直接 setState 会产生
///    "setState() or markNeedsBuild() called during build" 次生错误并反灌
///    诊断流——非 idle 相位一律 addPostFrameCallback 推迟；
/// 4. **severity 分流入口**：`_apply` 是 error/fatal → 卡片、warning → OSD
///    + 单次 dismissCurrent 的唯一分流点（D-02 分层，当前四个捕获源不产生
///    warning，该分支为 Phase 4/5 来源前瞻）；
/// 5. **适配 notifier（D-08/A5）**：见 `_presentation` 字段注释；
/// 6. **dispose 摘除**：removeListener + notifier dispose，幂等安全。
class ErrorCardHost extends StatefulWidget {
  /// Creates the presentation host; state is read from [ErrorReporterImpl.I].
  const ErrorCardHost({super.key});

  @override
  State<ErrorCardHost> createState() => _ErrorCardHostState();
}

class _ErrorCardHostState extends State<ErrorCardHost> {
  /// 宿主**自己的**适配 notifier —— build 里的 ValueListenableBuilder 读取它
  /// 而非 reporter.presentation（D-08/A5 记录）。
  ///
  /// 偏差理由：reporter 在 build 期同步发布（CARD-05 唯一已知失效路径），
  /// 直接订阅会在 persistentCallbacks 期间同步 markNeedsBuild。适配层吸收
  /// 通知并只在安全相位转发，保留了 D-08 的「ValueListenableBuilder 订阅
  /// 呈现状态」意图而不引入新状态库、零 kernel 结构改动。
  final ValueNotifier<ErrorPresentationState> _presentation =
      ValueNotifier<ErrorPresentationState>(
        const ErrorPresentationState(
          current: null,
          pendingCount: 0,
          isReady: false,
        ),
      );

  /// D-11 徽标轮览数据源 = [ErrorCaptureSnapshot]（呈现层有界快照，经
  /// reporter 既有 effects 缝维护，零 kernel 改动）—— 宿主只持轮览索引
  /// 这一个视图状态，不另存报告副本（单一数据源）。
  ///
  /// 轮览索引：0 = 最新（快照尾）；正数向旧偏移；新报告到达或手动关闭时
  /// 重置到 0。纯视图偏移 —— 轮览绝不写 reporter（T-03-10）。
  int _cycleIndex = 0;

  /// D-02 同帧防重标记：最近一次已分流的 warning eventId。
  ///
  /// 去重合并后的重发布（同 eventId 新快照实例）与相位守卫的两次帧尾回调
  /// 都会让 `_apply` 以同一 warning 被调用多次 —— 不防重就会重复
  /// dismissCurrent，静默丢弃队首后的待呈现错误（T-03-09/anti-pattern）。
  String? _lastWarningEventId;

  @override
  void initState() {
    super.initState();
    ErrorReporterImpl.I.presentation.addListener(_onPresentationChanged);
    // D-11：快照变化（effect 接纳新报告/合并/移除）同样触发重渲染；
    // 相位守卫与 presentation 通知一致（CARD-05：effect 可能在 build 期
    // 被 reporter fan-out 调用，直接 setState 会次生 markNeedsBuild）。
    ErrorCaptureSnapshot.I.reports.addListener(_onSnapshotChanged);
    // 吸收挂载前已发布的快照（isReady=false 的计数态），保证首帧前
    // 适配值与 reporter 一致。
    _onPresentationChanged();
    // D-12：首帧后宣布就绪，补呈现挂载前入队的错误。post-frame 相位内
    // 到达的通知同样被相位守卫推迟到下一帧落地。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ErrorReporterImpl.I.flushPresentation();
    });
  }

  @override
  void dispose() {
    ErrorReporterImpl.I.presentation.removeListener(_onPresentationChanged);
    ErrorCaptureSnapshot.I.reports.removeListener(_onSnapshotChanged);
    _presentation.dispose();
    super.dispose();
  }

  /// 快照变化 → 相位守卫重渲染（与 [_onPresentationChanged] 同一守卫纪律）：
  /// idle 同步 setState；build/layout/paint 与 post-frame 相位推迟到帧尾，
  /// 帧尾直接重读快照最新值（同帧多报告自然合并为一次重建）。
  ///
  /// CR-02：任何快照变化（新报告/合并/移除）都使轮览索引失效 —— 重置到 0
  /// （最新），保证 D-01「新报告替换卡片内容」不被残留偏移劫持：否则轮览
  /// 到旧条目后来新报告，偏移取模后显示的是位移后的陈旧条目而非新报告。
  void _onSnapshotChanged() {
    if (_cycleIndex != 0) _cycleIndex = 0;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      setState(() {});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// CARD-05 相位守卫：只有 idle 相位允许同步应用；build/layout/paint 与
  /// post-frame 相位（persistentCallbacks）到达的通知一律推迟。
  void _onPresentationChanged() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      _apply(ErrorReporterImpl.I.presentation.value);
    } else {
      // 在回调内部**重读** presentation.value（帧尾最新值，非调度时快照），
      // 同帧多报告由此自然合并为一次终值更新。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _apply(ErrorReporterImpl.I.presentation.value);
      });
    }
  }

  /// severity 分流入口（D-02 分层，03-03 完成版）：
  /// - `current == null` → 卡片隐藏（适配值置空）；
  /// - warning → OsdService 短暂提示 + 恰好一次 `dismissCurrent()`（队列
  ///   推进），warning 永不上卡片、不进快照 —— 呈现层过滤，无重建循环；
  /// - error/fatal → 更新适配 notifier（常驻卡片；快照维护由
  ///   [ErrorCaptureSnapshot] 经 effect 缝独立完成，宿主不存副本）。
  void _apply(ErrorPresentationState state) {
    // 相同快照短路：ValueNotifier.value setter 对 == 相等的值本就不再
    // 通知订阅者，这里显式短路避免无效赋值。
    if (_presentation.value == state) return;
    final report = state.current;
    if (report == null) {
      _presentation.value = state;
      return;
    }
    if (report.severity == ErrorSeverity.warning) {
      _routeWarning(report);
      return;
    }
    _presentation.value = state;
  }

  /// D-02 warning 分流：OSD 短暂提示（沿用 OsdService 默认时长）+ 恰好
  /// 一次 `dismissCurrent()` 推进队列。[_lastWarningEventId] 防同帧/同
  /// eventId 重复触发（T-03-09：重复 dismiss 会静默丢弃待呈现错误）。
  ///
  /// 注意：这里的 `dismissCurrent()` 是 D-02 分流**唯一**授权的非手动关闭
  /// 调用 —— 徽标轮览（[_cycleIndex]）绝不复用该路径。
  void _routeWarning(ErrorReport report) {
    if (report.eventId == _lastWarningEventId) return;
    _lastWarningEventId = report.eventId;
    OsdService.I.show(report.message, icon: Icons.warning_amber_outlined);
    ErrorReporterImpl.I.dismissCurrent();
  }

  /// 徽标轮览：沿快照向旧移动一格，越过最旧回到最新（循环语义）。
  ///
  /// 纯视图偏移 —— 只改渲染索引，不触碰 reporter 队列（T-03-10）；
  /// `dismissCurrent` 仅由手动关闭路径（[_onClose]）与 D-02 warning 分流
  /// 调用。
  void _cycleBadge() {
    setState(() => _cycleIndex += 1); // 渲染处按快照长度取模，无需在此钳制
  }

  /// CARD-01 手动关闭：dismissCurrent 消费**真实队首**（presentation.current，
  /// 而非轮览中显示的历史条目 —— research Anti-Pattern：dismiss 误用会永久
  /// 丢队首），快照同步移除该条（已关闭的错误不再计入徽标，D-11），
  /// 轮览重置到最新；随后 dismissCurrent 推进队列，下一项经 presentation
  /// 通知自然上屏（CAP-04）。
  void _onClose() {
    final head = ErrorReporterImpl.I.presentation.value.current;
    if (head != null) {
      ErrorCaptureSnapshot.I.removeById(head.eventId);
    }
    setState(() => _cycleIndex = 0);
    ErrorReporterImpl.I.dismissCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ErrorPresentationState>(
      valueListenable: _presentation,
      builder: (context, state, _) {
        // 隐藏门保持 03-01 语义：reporter 队列空（current == null）→ 卡片
        // 隐藏 —— 防止「关闭后快照残留项」形成永远关不掉的僵尸卡片。
        if (state.current == null) return const SizedBox.shrink();
        final history = ErrorCaptureSnapshot.I.reports.value;
        // 渲染报告取自快照（D-01/D-11）：非轮览显示**最新**（快照尾，即
        // D-01「新错误替换卡片内容」）；轮览中按索引向旧偏移（取模循环）。
        // 适配 notifier 保持 reporter 队首语义（CAP-04/dismissCurrent 的
        // 真实消费目标），渲染层的最新/轮览是纯视图偏移。
        final report = _displayedReport(history, state);
        if (report == null) return const SizedBox.shrink();
        // D-01/D-11 计数徽标 = 快照长度（已捕获且未被手动关闭的错误数，
        // 封顶 ErrorCaptureSnapshot.maxLength）。
        return ExcludeFocus(
          // CARD-01 前置：卡内无焦点可请求，键盘操作不会被卡片劫持。
          child: ErrorCard(
            report: report,
            totalCount: history.length,
            // D-01 徽标轮览接线（03-03）：纯视图偏移，不消费队列。
            onBadgeTap: _cycleBadge,
            // CARD-01 手动关闭唯一接线点：dismissCurrent 推进 FIFO，队首
            // 下一项经 presentation 通知自然上屏（CAP-04）。
            onClose: _onClose,
          ),
        );
      },
    );
  }

  /// 渲染层报告解析：快照非空时始终从快照取（最新或轮览偏移）；快照为空
  /// （未挂 effect 的极简测试环境）时退回 presentation.current（防御）。
  ErrorReport? _displayedReport(
    List<ErrorReport> history,
    ErrorPresentationState state,
  ) {
    if (history.isEmpty) return state.current;
    final offset = _cycleIndex % history.length;
    return history[history.length - 1 - offset];
  }
}
