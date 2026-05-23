import 'package:flutter/material.dart';

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
  bool _dragging = false;
  double _dragFraction = 0;
  final _hoverNotifier = ValueNotifier<_HoverState>(_HoverState.empty);
  DateTime _lastHoverUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _barWidth = 0;

  double get _hoverX => _hoverNotifier.value.x;

  double get _effectiveFraction {
    final dur = widget.engine.duration.value;
    if (dur <= 0) return 0;
    if (_dragging) return _dragFraction;
    return (widget.engine.position.value / dur).clamp(0.0, 1.0);
  }

  int get _dragPositionMs =>
      (_dragFraction * widget.engine.duration.value).round();

  int get _hoverPositionMs => (_hoverX * widget.engine.duration.value).round();

  MediaEngine get engine => widget.engine;

  @override
  void dispose() {
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
            final now = DateTime.now();
            if (now.difference(_lastHoverUpdate).inMilliseconds < 16) return;
            _lastHoverUpdate = now;
            _hoverNotifier.value = _HoverState(
              true,
              (details.localPosition.dx / barWidth).clamp(0.0, 1.0),
            );
          },
          child: Semantics(
            label: AppLocalizations.of(context).progressBar,
            value: '${(_effectiveFraction * 100).round()}%',
            slider: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                setState(() {
                  _dragging = true;
                  _dragFraction = (details.localPosition.dx / barWidth).clamp(
                    0.0,
                    1.0,
                  );
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragFraction = (details.localPosition.dx / barWidth).clamp(
                    0.0,
                    1.0,
                  );
                });
              },
              onHorizontalDragEnd: (_) {
                if (widget.engine.duration.value <= 0) {
                  setState(() => _dragging = false);
                  return;
                }
                final ms = _dragPositionMs;
                widget.engine.seekTo(ms);
                setState(() => _dragging = false);
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
                    if (_dragging) _buildDragTooltip(),
                    ValueListenableBuilder<_HoverState>(
                      valueListenable: _hoverNotifier,
                      builder: (_, hover, _) {
                        if (!hover.hovering ||
                            _dragging ||
                            widget.engine.duration.value <= 0) {
                          return const SizedBox.shrink();
                        }
                        return _buildHoverTooltip();
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
        animation: Listenable.merge([
          engine.position,
          engine.duration,
          engine.buffered,
        ]),
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
              dragging: _dragging,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragTooltip() {
    return Positioned(
      bottom: 24,
      left: (_dragFraction * _barWidth).clamp(40, _barWidth - 40).toDouble(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: Tokens.accent,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        ),
        child: Text(
          formatMs(_dragPositionMs),
          style: const TextStyle(
            color: Colors.white,
            fontSize: Tokens.fontOverline,
            fontFeatures: [Tokens.tabularFigures],
          ),
        ),
      ),
    );
  }

  Widget _buildHoverTooltip() {
    return Positioned(
      bottom: 24,
      left: (_hoverX * _barWidth).clamp(40, _barWidth - 40).toDouble(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: Tokens.bgGlass,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          border: Border.all(color: Tokens.borderHighlight, width: 0.5),
        ),
        child: Text(
          formatMs(_hoverPositionMs),
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontOverline,
            fontFeatures: [Tokens.tabularFigures],
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
