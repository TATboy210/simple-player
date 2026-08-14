import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 段落交错淡入动画包装器 — 用于设置面板 tab 切换时内容逐段浮现
///
/// 将 [children] 列表中的每个子组件按顺序以淡入动画依次显示，
/// 相邻子组件之间有 [staggerDelay] 的延迟间隔，营造视觉引导效果。
///
/// 典型用法：放在 ListView.children 内部，包裹所有内容段落。
/// 父级通过传入不同的 [Key] 强制重建，使动画在 tab 切换时重新播放。
class AnimatedSectionList extends StatefulWidget {
  /// 需要交错动画的内容段落
  final List<Widget> children;

  /// 相邻子组件动画启动间隔（默认 50ms）
  final Duration staggerDelay;

  /// 每个子组件的淡入持续时间（默认 300ms，与 Tokens.durationSlide 一致）
  final Duration animationDuration;

  const AnimatedSectionList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: Tokens.durationSlide),
  });

  @override
  State<AnimatedSectionList> createState() => _AnimatedSectionListState();
}

class _AnimatedSectionListState extends State<AnimatedSectionList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 总时长 = 最后一个子组件的开始时间 + 单个动画时长
    final totalStagger = widget.staggerDelay * widget.children.length;
    final totalDuration = totalStagger + widget.animationDuration;

    _controller = AnimationController(vsync: this, duration: totalDuration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _controller.duration?.inMilliseconds ?? 1;
    final animMs = widget.animationDuration.inMilliseconds;
    final staggerMs = widget.staggerDelay.inMilliseconds;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < widget.children.length; i++)
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _controller,
                  // 每个子组件的动画时间窗口，交错偏移
                  curve: Interval(
                    (staggerMs * i / totalMs).clamp(0.0, 1.0),
                    ((staggerMs * i + animMs) / totalMs).clamp(0.0, 1.0),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: widget.children[i],
            ),
        ],
      ),
    );
  }
}
