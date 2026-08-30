import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporter.dart';
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
///    的唯一分流点（warning 路由 03-03 接线，当前四个捕获源不产生 warning）；
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

  @override
  void initState() {
    super.initState();
    ErrorReporterImpl.I.presentation.addListener(_onPresentationChanged);
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
    _presentation.dispose();
    super.dispose();
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

  /// severity 分流入口：本计划只投影 error/fatal；warning → OsdService 的
  /// 路由在 03-03 接线（当前无产生 warning 的捕获源）。
  void _apply(ErrorPresentationState state) {
    // 相同快照短路：ValueNotifier.value setter 对 == 相等的值本就不再
    // 通知订阅者，这里显式短路避免无效赋值（Task 2 锁死该语义）。
    if (_presentation.value == state) return;
    _presentation.value = state;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ErrorPresentationState>(
      valueListenable: _presentation,
      builder: (context, state, _) {
        final report = state.current;
        if (report == null) return const SizedBox.shrink();
        // D-01 计数徽标 = 已捕获错误总数（含队首）：pendingCount 是队首
        // 之后的等待数，research 契约见 error_reporter._publishSafely。
        final totalCount = state.pendingCount + 1;
        return ExcludeFocus(
          // CARD-01 前置：卡内无焦点可请求，键盘操作不会被卡片劫持。
          child: ErrorCard(
            report: report,
            totalCount: totalCount,
            // CARD-01 手动关闭唯一接线点：dismissCurrent 推进 FIFO，队首
            // 下一项经 presentation 通知自然上屏（CAP-04）。徽标轮览
            // （03-03）不得复用此回调 —— 轮览只翻页不消费队列。
            onClose: () => ErrorReporterImpl.I.dismissCurrent(),
          ),
        );
      },
    );
  }
}
