import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 跑马灯文本 — 超出可用宽度时往返横向滚动以完整展示内容。
///
/// 行为：
/// - 文本宽度 ≤ 可用宽度 → 静止渲染（视觉与普通 [Text] 一致）
/// - 超长 → 以 [Tokens.titleMarqueeSpeed] px/s 往返滚动
///   （AnimationController.repeat(reverse: true)，端点无跳变）
/// - 系统开启"减少动画"（无障碍）→ 静止并按 ellipsis 截断
///
/// 仅支持单行（内部固定 maxLines: 1）。测量使用 [TextPainter]，
/// 仅在 LayoutBuilder build（宽度/文本/样式变化）时执行一次，无逐帧开销。
class MarqueeText extends StatefulWidget {
  /// 显示的文本（单行）。
  final String text;

  /// 文本样式，同时用于测量与渲染。
  final TextStyle? style;

  const MarqueeText({super.key, required this.text, this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  /// 往返滚动控制器 — 惰性创建，仅超长且允许动画时运行；
  /// 复用实例避免文本长短交替时反复建毁。
  AnimationController? _controller;

  /// 超出可用宽度的像素量 — 平移幅度与滚动时长的依据。
  double _overflow = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // build 中同步调整 controller（不调 setState）：宽度/文本变化只需
        // 更新 duration 与启停，无需额外重建 — LayoutBuilder 已是重建源头。
        _overflow = _measureTextWidth(context) - constraints.maxWidth;

        if (_overflow <= 0 || MediaQuery.disableAnimationsOf(context)) {
          _stopScrolling();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            // 放得下时 ellipsis 不生效；仅在超长且禁动画时兜底截断
            overflow: TextOverflow.ellipsis,
          );
        }
        return _buildScrollingText(_ensureScrolling());
      },
    );
  }

  /// 超长文本的往返滚动渲染 — ClipRect 裁剪平移出界的部分。
  Widget _buildScrollingText(AnimationController controller) {
    return RepaintBoundary(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          child: Text(widget.text, style: widget.style, maxLines: 1),
          builder: (context, child) => Transform.translate(
            // repeat(reverse: true) 使 value 在 0↔1 线性往返 → 平移无跳变
            offset: Offset(-_overflow * controller.value, 0),
            child: child,
          ),
        ),
      ),
    );
  }

  /// 取回滚动控制器，必要时创建，并保证其在滚动中。
  AnimationController _ensureScrolling() {
    final existing = _controller;
    if (existing != null) {
      // 滚动距离变化（resize/字号切换）→ 重算时长；相位保持，允许跳变
      existing.duration = _scrollDuration();
      if (!existing.isAnimating) {
        existing.repeat(reverse: true);
      }
      return existing;
    }
    final controller = AnimationController(
      vsync: this,
      duration: _scrollDuration(),
    );
    _controller = controller;
    controller.repeat(reverse: true);
    return controller;
  }

  /// 滚动一个完整单程所需时长 = 超出像素 / 恒定速度。
  Duration _scrollDuration() => Duration(
    milliseconds: (_overflow / Tokens.titleMarqueeSpeed * 1000).round(),
  );

  /// 停止滚动但保留控制器复用 — 文本长短可能在运行期交替变化。
  void _stopScrolling() {
    _controller?.stop();
  }

  /// 测量单行文本实际渲染宽度（含系统字体缩放）。
  double _measureTextWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
