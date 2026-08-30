/// debug 专用的全局错误钩子触发面板。
///
/// 仅在 `kDebugMode` 下由 [PlayerScreen] 挂载，用于人工验证全局错误捕获
/// 链路（CAP-01/CAP-02 UAT 人工项）：两个按钮分别走两条真实错误路径，
/// 观察每类来源恰好产生一份报告且应用不中断。生产构建完全不挂载。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/diagnostics/error_reporter.dart';
import '../theme/tokens.dart';

/// 错误触发按钮组：framework 回调异常 + 未捕获异步异常，并 debugPrint 报告流。
final class DebugErrorTriggers extends StatefulWidget {
  /// Creates the debug-only trigger panel.
  const DebugErrorTriggers({super.key});

  @override
  State<DebugErrorTriggers> createState() => _DebugErrorTriggersState();
}

final class _DebugErrorTriggersState extends State<DebugErrorTriggers> {
  /// 报告流观察回调；reporter 未初始化（如裸 widget test）时保持为 null。
  VoidCallback? _presentationListener;

  @override
  void initState() {
    super.initState();
    // widget test 可能未执行 main() 的 reporter 初始化，先探测再订阅。
    if (!ErrorReporterImpl.isInitialized) return;
    _presentationListener = () {
      final state = ErrorReporterImpl.I.presentation.value;
      final current = state.current;
      debugPrint(
        '[debug-error-triggers] 捕获成功: 队列现有 ${state.pendingCount + (current == null ? 0 : 1)} 份报告'
        '${current == null ? '' : '；当前展示: ${current.source.name} ${current.eventId} '
                  'x${current.occurrenceCount} "${current.message}"'}'
        '（isReady=${state.isReady}：false=暂无卡片宿主，属 Phase 3 交付，属预期）',
      );
    };
    ErrorReporterImpl.I.presentation.addListener(_presentationListener!);
  }

  @override
  void dispose() {
    final listener = _presentationListener;
    if (listener != null && ErrorReporterImpl.isInitialized) {
      ErrorReporterImpl.I.presentation.removeListener(listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ErrorReporterImpl.isInitialized) {
      // 无 reporter 环境下不可用，直接不渲染。
      return const SizedBox.shrink();
    }
    return Material(
      color: Tokens.bgGlass,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              // 在手势回调内同步抛出 → Flutter framework 捕获 → FlutterError.onError
              // → reportFlutterSafely（真实 framework 路径）。
              onPressed: () => throw StateError(
                'debug-trigger: framework hook test (onPressed 同步抛出)',
              ),
              child: const Text(
                '触发框架异常',
                style: TextStyle(fontSize: 11, color: Tokens.textPrimary),
              ),
            ),
            TextButton(
              // 微任务内未捕获抛出 → runZonedGuarded onError → reportBootstrapSafely
              // （本项目 main.dart 拓扑下未捕获异步异常的真实路径）。
              onPressed: () => scheduleMicrotask(
                () =>
                    throw StateError('debug-trigger: async hook test (微任务未捕获)'),
              ),
              child: const Text(
                '触发异步异常',
                style: TextStyle(fontSize: 11, color: Tokens.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
