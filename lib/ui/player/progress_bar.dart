import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../kernel/engine/media_engine.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';

class _HoverState {
  const _HoverState(this.hovering, this.x);
  static const empty = _HoverState(false, 0.0);
  final bool hovering;
  final double x;
}

/// 进度条 — 已播放/已缓冲/未播放三层，拖拽 seek + 时间提示
class ProgressBar extends StatefulWidget {
  final MediaEngine engine;

  const ProgressBar({super.key, required this.engine});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  /// null = 未拖拽，非 null = 拖拽中的 fraction
  final _dragNotifier = ValueNotifier<double?>(null);
  final _hoverNotifier = ValueNotifier<_HoverState>(_HoverState.empty);
  double _barWidth = 0;

  late final Listenable _barListenable;
  Timer? _seekThrottle;
  bool _hoverScheduled = false;

  double get _hoverX => _hoverNotifier.value.x;

  double get _effectiveFraction {
    final dur = widget.engine.duration.value;
    if (dur <= 0) return 0;
    final drag = _dragNotifier.value;
    if (drag != null) return drag;
    return (widget.engine.position.value / dur).clamp(0.0, 1.0);
  }

  int get _dragPositionMs =>
      ((_dragNotifier.value ?? 0) * widget.engine.duration.value).round();

  int get _hoverPositionMs => (_hoverX * widget.engine.duration.value).round();

  MediaEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _barListenable = Listenable.merge([
      engine.position,
      engine.duration,
      engine.buffered,
      _dragNotifier,
    ]);
  }

  @override
  void dispose() {
    _seekThrottle?.cancel();
    _dragNotifier.dispose();
    _hoverNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        _barWidth = barWidth;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _hoverNotifier.value = _HoverState(true, _hoverX),
          onExit: (_) => _hoverNotifier.value = _HoverState.empty,
          onHover: (details) {
            if (_hoverScheduled) return;
            _hoverScheduled = true;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _hoverScheduled = false;
              if (!mounted) return;
              _hoverNotifier.value = _HoverState(
                true,
                (details.localPosition.dx / barWidth).clamp(0.0, 1.0),
              );
            });
          },
          child: Semantics(
            label: AppLocalizations.of(context).progressBar,
            value: '${(_effectiveFraction * 100).round()}%',
            slider: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                _dragNotifier.value = (details.localPosition.dx / barWidth)
                    .clamp(0.0, 1.0);
              },
              onHorizontalDragUpdate: (details) {
                _dragNotifier.value = (details.localPosition.dx / barWidth)
                    .clamp(0.0, 1.0);
                // 节流 seek：拖拽期间每 150ms 更新一次视频帧
                _seekThrottle?.cancel();
                _seekThrottle = Timer(const Duration(milliseconds: 150), () {
                  if (_dragNotifier.value != null &&
                      widget.engine.duration.value > 0) {
                    widget.engine.seekTo(_dragPositionMs);
                  }
                });
              },
              onHorizontalDragEnd: (_) {
                _seekThrottle?.cancel();
                if (widget.engine.duration.value <= 0) {
                  _dragNotifier.value = null;
                  return;
                }
                widget.engine.seekTo(_dragPositionMs);
                _dragNotifier.value = null;
              },
              onTapDown: (details) {
                if (widget.engine.duration.value <= 0) return;
                final fraction = (details.localPosition.dx / barWidth).clamp(
                  0.0,
                  1.0,
                );
                final ms = (fraction * widget.engine.duration.value).round();
                widget.engine.seekTo(ms);
              },
              child: SizedBox(
                height: Tokens.progressBarHeight,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _buildBarLayers(),
                    if (_dragNotifier.value != null)
                      _buildTooltip(
                        fraction: _dragNotifier.value!,
                        text: formatMs(_dragPositionMs),
                        bgColor: Tokens.accent,
                        textColor: Colors.white,
                      ),
                    ValueListenableBuilder<_HoverState>(
                      valueListenable: _hoverNotifier,
                      builder: (_, hover, _) {
                        if (!hover.hovering ||
                            _dragNotifier.value != null ||
                            widget.engine.duration.value <= 0) {
                          return const SizedBox.shrink();
                        }
                        return _buildTooltip(
                          fraction: _hoverX,
                          text: formatMs(_hoverPositionMs),
                          bgColor: Tokens.bgGlass,
                          textColor: Tokens.textPrimary,
                          border: Border.all(
                            color: Tokens.borderHighlight,
                            width: 0.5,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarLayers() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _barListenable,
        builder: (_, _) {
          final dur = engine.duration.value;
          final buf = engine.buffered.value;
          final playedFrac = _effectiveFraction;
          final bufFrac = dur > 0 ? (buf / dur).clamp(0.0, 1.0) : 0.0;
          return CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(
              playedFraction: playedFrac,
              bufferedFraction: bufFrac,
              dragging: _dragNotifier.value != null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTooltip({
    required double fraction,
    required String text,
    required Color bgColor,
    required Color textColor,
    Border? border,
  }) {
    return Positioned(
      bottom: 24,
      left: (fraction * _barWidth).clamp(40, _barWidth - 40).toDouble(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          border: border,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: Tokens.fontOverline,
            fontFeatures: const [Tokens.tabularFigures],
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double playedFraction;
  final double bufferedFraction;
  final bool dragging;

  _BarPainter({
    required this.playedFraction,
    required this.bufferedFraction,
    required this.dragging,
  });

  static final _bgPaint = Paint()..color = Tokens.bgHover;
  static final _bufPaint = Paint()..color = Tokens.progressBuffer;
  static final _playedPaint = Paint()..color = Tokens.progressPlayed;
  static final _thumbPaint = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = dragging
        ? Tokens.progressBarThicknessDrag
        : Tokens.progressBarThickness;
    final top = size.height - barHeight;

    canvas.drawRect(Rect.fromLTWH(0, top, size.width, barHeight), _bgPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width * bufferedFraction, barHeight),
      _bufPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width * playedFraction, barHeight),
      _playedPaint,
    );

    if (dragging) {
      final thumbX = size.width * playedFraction;
      canvas.drawCircle(
        Offset(thumbX, top + barHeight / 2),
        Tokens.progressThumbRadius,
        _thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.playedFraction != playedFraction ||
      old.bufferedFraction != bufferedFraction ||
      old.dragging != dragging;
}
