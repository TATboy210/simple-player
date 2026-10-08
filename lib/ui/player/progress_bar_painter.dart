part of 'progress_bar.dart';

/// 进度绘制 — same-library extraction; paint objects and repaint policy unchanged.
class _BarPainter extends CustomPainter {
  final double playedFraction;
  final bool dragging;
  final double barHeight;
  final double? hoverFraction;
  final bool disabled;

  _BarPainter({
    required this.playedFraction,
    required this.dragging,
    required this.barHeight,
    this.hoverFraction,
    required this.disabled,
  });

  static final _bgPaint = Paint()..color = Tokens.bgHover;
  static final _bgDisabledPaint = Paint()
    ..color = Tokens.bgHover.withValues(alpha: Tokens.progressDisabledBgAlpha);
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
      old.dragging != dragging ||
      old.barHeight != barHeight ||
      old.hoverFraction != hoverFraction ||
      old.disabled != disabled;
}
