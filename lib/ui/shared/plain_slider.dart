import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// 轻量滑条 — 无 OverlayPortal 的 Material [Slider] 替身.
///
/// Material [Slider] 恒挂一个值指示器 `OverlayPortal` (slider.dart 内
/// `OverlayPortalController()..show()`, showValueIndicator 也关不掉).
/// 该层的语义节点挂在 Overlay 根下而非滑条子树, Windows 无障碍桥每次
/// 语义更新都报 `Failed to update ui::AXTree` 并整树重建 — 控制栏常驻的
/// 音量条让鼠标移动 / 播放进度更新都触发这条错误洪流与卡顿.
///
/// 本控件只用普通子树: [Semantics] (slider 角色 + 增减动作) + [Focus]
/// (方向键) + 水平拖动手势 + [CustomPaint]. 回调序列与 Material 对齐:
/// - 指针: 按下 onChangeStart(旧值) → onChanged(落点值)…→ onChangeEnd;
///   手势被取消 (含竞技场落败的轻点) 同样以 onChangeEnd 收尾.
/// - 键盘 / 无障碍增减: 只发 onChanged (不发 start/end), 步长为区间 5%.
class PlainSlider extends StatefulWidget {
  const PlainSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.onChangeStart,
    this.onChangeEnd,
    this.focusNode,
    this.activeColor = Tokens.accent,
    this.inactiveColor = Tokens.bgHover,
    this.trackHeight = 3,
    this.thumbRadius = 5,
    this.overlayRadius = 10,
  });

  final double value;
  final double min;
  final double max;

  /// null = 禁用 (不响应指针/键盘, 语义标记 disabled).
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final FocusNode? focusNode;
  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;
  final double thumbRadius;

  /// 交互光晕半径 — 同时决定控件高度 (2×) 与轨道左右内缩, 与 Material
  /// overlayShape 的布局语义一致, 替换后控件尺寸不变.
  final double overlayRadius;

  /// 键盘 / 语义增减步长 (占区间比例) — 对齐 Material 无 divisions 时的 0.05.
  static const double keyboardStep = 0.05;

  @override
  State<PlainSlider> createState() => _PlainSliderState();
}

class _PlainSliderState extends State<PlainSlider> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'slider'));

  bool _dragging = false;
  bool _hovered = false;
  bool _focused = false;

  /// 拖动中最近一次报告的值 — 取消/结束时作为 onChangeEnd 参数.
  double _lastValue = 0;

  bool get _enabled => widget.onChanged != null;
  double get _span => widget.max - widget.min;

  /// value → [0,1] 归一化 (区间退化时恒 0, 防除零).
  double get _fraction =>
      _span <= 0 ? 0 : ((widget.value - widget.min) / _span).clamp(0.0, 1.0);

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  /// 本地横坐标 → 值 (轨道左右各内缩 overlayRadius).
  double _valueAt(double dx, double width) {
    final inset = widget.overlayRadius;
    final track = width - inset * 2;
    final t = track <= 0 ? 0.0 : ((dx - inset) / track).clamp(0.0, 1.0);
    return widget.min + t * _span;
  }

  void _start(Offset local, double width) {
    if (!_enabled) return;
    _dragging = true;
    widget.onChangeStart?.call(widget.value);
    _update(local, width);
    setState(() {});
  }

  void _update(Offset local, double width) {
    if (!_dragging) return;
    _lastValue = _valueAt(local.dx, width);
    widget.onChanged?.call(_lastValue);
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    widget.onChangeEnd?.call(_lastValue);
    if (mounted) setState(() {});
  }

  /// 键盘 / 语义动作单步 — 只发 onChanged (Material 同语义).
  void _step(int direction) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final next = (widget.value + direction * PlainSlider.keyboardStep * _span)
        .clamp(widget.min, widget.max);
    onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _percent(double fraction) => '${(fraction * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final fraction = _fraction;
    final step = PlainSlider.keyboardStep;
    return Semantics(
      slider: true,
      enabled: _enabled,
      focusable: _enabled,
      value: _percent(fraction),
      increasedValue: _percent((fraction + step).clamp(0.0, 1.0)),
      decreasedValue: _percent((fraction - step).clamp(0.0, 1.0)),
      onIncrease: _enabled ? () => _step(1) : null,
      onDecrease: _enabled ? () => _step(-1) : null,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: _enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          // hover 只在进出时 setState 一次 — 移动不触发重建.
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: SizedBox(
            height: widget.overlayRadius * 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragDown: (d) => _start(d.localPosition, width),
                  onHorizontalDragUpdate: (d) =>
                      _update(d.localPosition, width),
                  onHorizontalDragEnd: (_) => _end(),
                  onHorizontalDragCancel: _end,
                  child: CustomPaint(
                    size: Size(width, widget.overlayRadius * 2),
                    painter: _PlainSliderPainter(
                      fraction: fraction,
                      active: widget.activeColor,
                      inactive: widget.inactiveColor,
                      trackHeight: widget.trackHeight,
                      thumbRadius: widget.thumbRadius,
                      overlayRadius: widget.overlayRadius,
                      // 光晕: 悬停/聚焦淡显, 拖动加深 — 对齐 Material 反馈.
                      overlayAlpha: _dragging
                          ? 0.24
                          : (_hovered || _focused)
                          ? 0.12
                          : 0.0,
                      enabled: _enabled,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 轨道 + 已激活段 + 光晕 + 拇指. 纯函数式绘制, 仅参数变化时重绘.
class _PlainSliderPainter extends CustomPainter {
  const _PlainSliderPainter({
    required this.fraction,
    required this.active,
    required this.inactive,
    required this.trackHeight,
    required this.thumbRadius,
    required this.overlayRadius,
    required this.overlayAlpha,
    required this.enabled,
  });

  final double fraction;
  final Color active;
  final Color inactive;
  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;
  final double overlayAlpha;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = overlayRadius;
    final right = size.width - overlayRadius;
    if (right <= left) return;
    final thumbX = left + (right - left) * fraction;
    final radius = Radius.circular(trackHeight / 2);
    final activeColor = enabled ? active : active.withValues(alpha: 0.38);

    final paint = Paint()..color = inactive;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        cy - trackHeight / 2,
        right,
        cy + trackHeight / 2,
        radius,
      ),
      paint,
    );
    paint.color = activeColor;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        cy - trackHeight / 2,
        thumbX,
        cy + trackHeight / 2,
        radius,
      ),
      paint,
    );
    if (overlayAlpha > 0) {
      paint.color = active.withValues(alpha: overlayAlpha);
      canvas.drawCircle(Offset(thumbX, cy), overlayRadius, paint);
    }
    paint.color = activeColor;
    canvas.drawCircle(Offset(thumbX, cy), thumbRadius, paint);
  }

  @override
  bool shouldRepaint(_PlainSliderPainter old) =>
      old.fraction != fraction ||
      old.active != active ||
      old.inactive != inactive ||
      old.trackHeight != trackHeight ||
      old.thumbRadius != thumbRadius ||
      old.overlayRadius != overlayRadius ||
      old.overlayAlpha != overlayAlpha ||
      old.enabled != enabled;
}
