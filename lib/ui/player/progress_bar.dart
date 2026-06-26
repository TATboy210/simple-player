import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:player_engine/player_engine.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';

class _HoverState {
  const _HoverState(this.hovering, this.x);
  static const empty = _HoverState(false, 0.0);
  final bool hovering;
  final double x;
}

/// 进度条 — 已播放/已缓冲/未播放三层圆角矩形
/// 支持：拖拽 seek（节流+阈值）、悬停展开动画、Tooltip 淡入淡出、
/// 滚轮 seek、悬停 thumb、禁用状态、缓冲指示器
class ProgressBar extends StatefulWidget {
  final PlayerEngine engine;

  /// Window resize signal — when true, skip internal bar rebuild to save CPU.
  final ValueListenable<bool>? resizing;

  const ProgressBar({super.key, required this.engine, this.resizing});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar>
    with TickerProviderStateMixin {
  final _dragNotifier = ValueNotifier<double?>(null);
  final _hoverNotifier = ValueNotifier<_HoverState>(_HoverState.empty);
  double _barWidth = 0;
  bool _reducedMotion = false;
  double? _dragStartX;

  late Listenable _barListenable;
  Timer? _seekThrottle;
  bool _hoverScheduled = false;

  // Tooltip 淡入淡出动画
  late final AnimationController _tooltipFadeController;
  late final Animation<double> _tooltipOpacity;

  // 悬停展开动画（3dp → 5dp）
  late final AnimationController _expandController;
  late final Animation<double> _barHeightAnimation;

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

  bool get _disabled => widget.engine.duration.value <= 0;

  PlayerEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _barListenable = _buildBarListenable();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: Tokens.progressExpandDurationMs),
      vsync: this,
    );
    _barHeightAnimation =
        Tween<double>(
          begin: Tokens.progressBarThickness,
          end: Tokens.progressBarThicknessDrag,
        ).animate(
          CurvedAnimation(parent: _expandController, curve: Curves.easeOut),
        );
    _tooltipFadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _tooltipOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tooltipFadeController, curve: Curves.easeOut),
    );
  }

  Listenable _buildBarListenable() {
    final listenables = <Listenable>[
      engine.position,
      engine.duration,
      engine.buffered,
      _dragNotifier,
      _hoverNotifier,
    ];
    final resizing = widget.resizing;
    if (resizing != null) listenables.add(resizing);
    return Listenable.merge(listenables);
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine ||
        oldWidget.resizing != widget.resizing) {
      _barListenable = _buildBarListenable();
    }
  }

  @override
  void dispose() {
    _seekThrottle?.cancel();
    _dragNotifier.dispose();
    _hoverNotifier.dispose();
    _expandController.dispose();
    _tooltipFadeController.dispose();
    super.dispose();
  }

  void _updateTooltipVisibility() {
    if (_reducedMotion) return;
    final show = _hoverNotifier.value.hovering || _dragNotifier.value != null;
    if (show) {
      _expandController.forward();
      _tooltipFadeController.forward();
    } else {
      _expandController.reverse();
      _tooltipFadeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        _barWidth = barWidth;
        return MouseRegion(
          cursor: _disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) {
            if (_disabled) return;
            _hoverNotifier.value = _HoverState(true, _hoverX);
            _updateTooltipVisibility();
          },
          onExit: (_) {
            // 拖拽中不重置 hover，防止松手时 thumb 闪跳到 0.0
            if (_dragNotifier.value != null) return;
            _hoverNotifier.value = _HoverState.empty;
            _updateTooltipVisibility();
          },
          onHover: (details) {
            if (_disabled) return;
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
              onHorizontalDragStart: _disabled
                  ? null
                  : (details) {
                      _dragStartX = details.localPosition.dx;
                      _updateTooltipVisibility();
                    },
              onHorizontalDragUpdate: _disabled
                  ? null
                  : (details) {
                      final dx = details.localPosition.dx;
                      // 拖拽阈值：防止误触
                      if (_dragNotifier.value == null) {
                        final start = _dragStartX;
                        if (start != null &&
                            (dx - start).abs() <
                                Tokens.progressDragThreshold) {
                          return;
                        }
                        _dragStartX = null;
                      }
                      _dragNotifier.value = (dx / barWidth).clamp(0.0, 1.0);
                      _seekThrottle?.cancel();
                      _seekThrottle = Timer(
                        const Duration(
                          milliseconds: Tokens.progressSeekThrottleMs,
                        ),
                        () {
                          if (_dragNotifier.value != null &&
                              widget.engine.duration.value > 0) {
                            widget.engine.seekTo(_dragPositionMs);
                          }
                        },
                      );
                    },
              onHorizontalDragEnd: _disabled
                  ? null
                  : (_) {
                      _dragStartX = null;
                      _seekThrottle?.cancel();
                      if (_dragNotifier.value == null) return;
                      if (widget.engine.duration.value <= 0) {
                        _dragNotifier.value = null;
                        _updateTooltipVisibility();
                        return;
                      }
                      widget.engine.seekTo(_dragPositionMs);
                      _dragNotifier.value = null;
                      // 恢复悬停状态（鼠标仍在 bar 上）
                      _hoverNotifier.value = _HoverState(true, _hoverX);
                      _updateTooltipVisibility();
                    },
              onTapDown: _disabled
                  ? null
                  : (details) {
                      if (widget.engine.duration.value <= 0) return;
                      final fraction = (details.localPosition.dx / barWidth)
                          .clamp(0.0, 1.0);
                      final ms = (fraction * widget.engine.duration.value)
                          .round();
                      widget.engine.seekTo(ms);
                    },
              child: SizedBox(
                height: Tokens.progressBarHeight,
                child: AnimatedBuilder(
                  animation: _barHeightAnimation,
                  builder: (_, _) => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _buildBarLayers(),
                      // 悬停/拖拽时间提示
                      ValueListenableBuilder<_HoverState>(
                        valueListenable: _hoverNotifier,
                        builder: (_, hover, _) {
                          final isDragging = _dragNotifier.value != null;
                          final fraction = isDragging
                              ? _dragNotifier.value!
                              : hover.hovering
                              ? hover.x
                              : null;
                          if (fraction == null || _disabled) {
                            return const SizedBox.shrink();
                          }
                          return _buildTooltip(
                            fraction: fraction,
                            text: formatMs(
                              (fraction * engine.duration.value).round(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _cachedCustomPaint;

  Widget _buildBarLayers() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _barListenable,
        builder: (_, _) {
          final resizing = widget.resizing;
          if (resizing != null && resizing.value) {
            return _cachedCustomPaint ?? const SizedBox.shrink();
          }
          final dur = engine.duration.value;
          final buf = engine.buffered.value;
          final playedFrac = _effectiveFraction;
          final bufFrac = dur > 0 ? (buf / dur).clamp(0.0, 1.0) : 0.0;
          final child = CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(
              playedFraction: playedFrac,
              bufferedFraction: bufFrac,
              dragging: _dragNotifier.value != null,
              barHeight: _barHeightAnimation.value,
              hoverFraction: _hoverNotifier.value.hovering ? _hoverX : null,
              disabled: _disabled,
            ),
          );
          _cachedCustomPaint = child;
          return child;
        },
      ),
    );
  }

  Widget _buildTooltip({required double fraction, required String text}) {
    const tooltipWidth = 52.0;
    const tooltipOffset = 20.0;
    final halfW = tooltipWidth / 2 + Tokens.spXs;
    final left = (fraction * _barWidth - tooltipWidth / 2)
        .clamp(halfW, _barWidth - halfW)
        .toDouble();
    return Positioned(
      bottom: tooltipOffset,
      left: left,
      child: FadeTransition(
        opacity: _tooltipOpacity,
        child: Container(
            width: tooltipWidth,
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spXs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Tokens.bgGlass,
              borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              border: Border.all(color: Tokens.borderHighlight, width: 0.5),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontOverline,
                fontFeatures: [Tokens.tabularFigures],
              ),
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
  final double barHeight;
  final double? hoverFraction;
  final bool disabled;

  _BarPainter({
    required this.playedFraction,
    required this.bufferedFraction,
    required this.dragging,
    required this.barHeight,
    this.hoverFraction,
    required this.disabled,
  });

  static final _bgPaint = Paint()..color = Tokens.bgHover;
  static final _bgDisabledPaint = Paint()
    ..color = Tokens.bgHover.withValues(alpha: Tokens.progressDisabledBgAlpha);
  static final _bufPaint = Paint()..color = Tokens.progressBuffer;
  static final _bufDisabledPaint = Paint()
    ..color = Tokens.progressBuffer.withValues(
      alpha: Tokens.progressDisabledBufferAlpha,
    );
  static final _playedPaint = Paint()..color = Tokens.progressPlayed;
  static final _playedDisabledPaint = Paint()
    ..color = Tokens.progressPlayed.withValues(
      alpha: Tokens.progressDisabledPlayedAlpha,
    );
  static final _thumbPaint = Paint()..color = Tokens.progressThumb;

  static const _thumbWidth = 18.0;
  static const _thumbHeight = 12.0;
  static const _thumbRadius = Radius.circular(2.0);

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - barHeight) / 2;

    final bg = disabled ? _bgDisabledPaint : _bgPaint;
    final buf = disabled ? _bufDisabledPaint : _bufPaint;
    final played = disabled ? _playedDisabledPaint : _playedPaint;

    const radius = Radius.circular(Tokens.progressBarRadius);

    // 背景层（圆角）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, barHeight),
        radius,
      ),
      bg,
    );
    // 缓冲层（圆角）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width * bufferedFraction, barHeight),
        radius,
      ),
      buf,
    );
    // 已播放层（圆角）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width * playedFraction, barHeight),
        radius,
      ),
      played,
    );

    // thumb 始终显示在播放进度位置（不跟随鼠标）
    if (!disabled) {
      final cx = size.width * playedFraction;
      final cy = top + barHeight / 2;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: _thumbWidth,
        height: _thumbHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, _thumbRadius),
        _thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.playedFraction != playedFraction ||
      old.bufferedFraction != bufferedFraction ||
      old.dragging != dragging ||
      old.barHeight != barHeight ||
      old.hoverFraction != hoverFraction ||
      old.disabled != disabled;
}
