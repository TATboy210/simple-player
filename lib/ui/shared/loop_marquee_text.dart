import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 循环跑马灯文本 — 空间足够时静止全显，不足时从右向左循环滚动。
///
/// 与 [MarqueeText]（往返滚动）同族的单向循环变体：
/// - 文本宽度 ≤ 可用宽度 → 静止渲染（视觉与普通 [Text] 一致）
/// - 超长 → 文本 + 间隙拼两份平铺，整体从右向左单向循环
///   （AnimationController.repeat + Transform.translate 渲染层合成，
///   widget 树零重建）；滚完整轮后停顿 [pauseAfterRound] 再续
/// - 系统开启"减少动画"（无障碍）→ 静止并按 ellipsis 截断
///
/// 仅支持单行（内部固定 maxLines: 1 + softWrap: false — 缺省折行会把
/// 超宽字形在布局期裁掉，尾部内容永远滚不出来）。测量使用 [TextPainter]，
/// 仅在 LayoutBuilder build（宽度/文本/样式变化）时执行一次，读完即 dispose。
class LoopMarqueeText extends StatefulWidget {
  /// 显示的文本（单行）。
  final String text;

  /// 文本样式，同时用于测量与渲染。
  final TextStyle? style;

  const LoopMarqueeText({super.key, required this.text, this.style});

  @override
  State<LoopMarqueeText> createState() => _LoopMarqueeTextState();
}

class _LoopMarqueeTextState extends State<LoopMarqueeText>
    with SingleTickerProviderStateMixin {
  /// 循环滚动控制器 — 惰性创建，仅超长且允许动画时运行。
  AnimationController? _controller;

  /// 测量得到的单行行高 — 收紧滚动分支高度（OverflowBox 需有界高约束）.
  double _textHeight = 0;

  /// 两份文本之间及循环接缝的空隙宽度。
  static const double _gap = 24.0;

  /// 滚完整轮后的停顿时长 — 给读者看清尾段时间.
  static const Duration _pauseAfterRound = Duration(milliseconds: 1200);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = _measureTextWidth(context);
        final overflow = textWidth - constraints.maxWidth;

        // 静止条件：放得下，或系统要求减少动画。
        if (overflow <= 0 || MediaQuery.disableAnimationsOf(context)) {
          _stopScrolling();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
            // 放得下时 ellipsis 不生效；仅在超长且禁动画时兜底截断
            overflow: TextOverflow.ellipsis,
          );
        }
        return _buildLoopingText(textWidth, _ensureLooping(textWidth));
      },
    );
  }

  /// 超长文本的单向循环滚动渲染 — OverflowBox 放开 Row 的宽约束
  /// （Transform.translate 是 paint 层，救不了解约束期的 Flex overflow
  /// 断言），ClipRect 裁剪平移出界的部分；外层 SizedBox 用测量行高
  /// 收紧高度（OverflowBox 未设高约束会继承父链无界高而取无限尺寸）.
  Widget _buildLoopingText(double textWidth, AnimationController controller) {
    final travel = textWidth + _gap;
    return RepaintBoundary(
      child: ClipRect(
        child: SizedBox(
          height: _textHeight,
          // alignment 必须 centerLeft：默认 center 会把超宽子内容居中错位.
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: controller,
              // child 恒定 — 动画帧只换 Transform 矩阵，Row 零重建.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  const SizedBox(width: _gap),
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
              builder: (context, child) {
                // 相位：滚动段线性推进，暂停段保持末值（1.0 → 回卷 0 无缝）.
                final total = controller.duration!.inMilliseconds;
                final scrollMs = total - _pauseAfterRound.inMilliseconds;
                final t = controller.value;
                final phase = t * total < scrollMs
                    ? (t * total) / scrollMs
                    : 1.0;
                return Transform.translate(
                  offset: Offset(-phase * travel, 0),
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 取回循环控制器，必要时创建，并保证其在循环中。
  AnimationController _ensureLooping(double textWidth) {
    final travel = textWidth + _gap;
    // 时长 = 滚动段（travel / 恒定速度）+ 暂停段.
    final duration = Duration(
      milliseconds:
          (travel / Tokens.titleMarqueeSpeed * 1000).round() +
          _pauseAfterRound.inMilliseconds,
    );
    final existing = _controller;
    if (existing != null) {
      // 滚动距离变化（resize/字号切换）→ 重算时长；相位保持，允许跳变.
      existing.duration = duration;
      if (!existing.isAnimating) {
        existing.repeat();
      }
      return existing;
    }
    final controller = AnimationController(vsync: this, duration: duration);
    _controller = controller;
    controller.repeat();
    return controller;
  }

  /// 停止循环但保留控制器复用 — 文本长短可能在运行期交替变化。
  void _stopScrolling() {
    _controller?.stop();
  }

  /// 测量缓存 — 测量结果只依赖 (text, style, textScaler)；hover/选中态
  /// setState 重建时命中缓存跳过 TextPainter（4 chip × 每次 0.1-0.4ms）.
  String? _cacheText;
  TextStyle? _cacheStyle;
  double? _cacheScale;
  double? _cacheWidth;

  /// 测量单行文本渲染宽度与行高（含系统字体缩放）。缓存命中零成本；
  /// 未命中时现测、读完即 dispose。
  double _measureTextWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1.0);
    if (_cacheText == widget.text &&
        identical(_cacheStyle, widget.style) &&
        _cacheScale == scale &&
        _cacheWidth != null) {
      return _cacheWidth!;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    _textHeight = painter.height;
    painter.dispose();
    _cacheText = widget.text;
    _cacheStyle = widget.style;
    _cacheScale = scale;
    _cacheWidth = width;
    return width;
  }
}
