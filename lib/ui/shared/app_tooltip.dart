import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 播放器交互提示的统一包装器。
///
/// 动作提示和状态提示共享同一视觉与延迟策略；实时播放反馈（例如进度条
/// 时间气泡）不应使用此组件，因为它们需要跟随指针持续更新。
class AppTooltip extends StatelessWidget {
  /// 要显示的提示文本；为空时直接返回 [child]，避免空语义节点。
  final String? message;

  /// 被提示包装的控件。
  final Widget child;

  /// 提示出现前的等待时间；截断补全类提示通常使用更长延迟。
  final Duration waitDuration;

  /// 创建统一的播放器 Tooltip。
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: Tokens.tooltipDelayShort),
  });

  @override
  Widget build(BuildContext context) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return child;

    return Tooltip(
      message: text,
      waitDuration: waitDuration,
      child: child,
    );
  }
}
