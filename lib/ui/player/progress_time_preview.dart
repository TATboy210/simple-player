part of 'progress_bar.dart';

/// 时间预览 — natural measured text in the current route overlay, outside bar clip.
///
/// The portal shares the bar's inherited text scale and follows its live paint
/// transform on layout. It owns no timer, focus, seek state or animation.
class _ProgressTimePreview extends StatefulWidget {
  const _ProgressTimePreview({
    required this.fraction,
    required this.text,
    required this.barWidth,
    required this.opacity,
  });

  final double fraction;
  final String text;
  final double barWidth;
  final Animation<double> opacity;

  @override
  State<_ProgressTimePreview> createState() => _ProgressTimePreviewState();
}

class _ProgressTimePreviewState extends State<_ProgressTimePreview> {
  // Hover/drag still owns mounting and opacity; the retained bar owner gates
  // physical overlay visibility because Offstage does not clip portal painting.
  final _portal = OverlayPortalController()..show();
  ValueNotifier<bool>? _owner;
  bool _isCurrent = true;
  bool _active = true;
  bool _syncQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = SecondarySurfaceVisibility.maybeOf(context);
    if (!identical(owner, _owner)) {
      _owner?.removeListener(_syncPortal);
      _owner = owner;
      _owner?.addListener(_syncPortal);
    }
    _isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncPortal();
  }

  @override
  void didUpdateWidget(_ProgressTimePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPortal();
  }

  bool get _eligible => _active && _isCurrent && _owner?.value != false;

  /// Borrow only live eligibility; never change the bar's hover or seek clocks.
  void _syncPortal() {
    // Controller mutation is forbidden during build. Layout also gates outgoing
    // paint, so the queued reconciliation cannot flash a hidden owner's popup.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_syncQueued) return;
      _syncQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncQueued = false;
        if (mounted) _syncPortal();
      });
      return;
    }
    if (_eligible == _portal.isShowing) return;
    if (_eligible) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  @override
  void deactivate() {
    _active = false;
    _syncPortal();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    // Inherited dependencies refresh before paint; reconcile even when a cached
    // child is reparented without receiving a new widget configuration.
    _syncPortal();
  }

  @override
  void dispose() {
    _owner?.removeListener(_syncPortal);
    super.dispose();
  }

  static const _style = TextStyle(
    color: Tokens.textPrimary,
    fontSize: Tokens.fontOverline,
    fontFeatures: [Tokens.tabularFigures],
  );
  static const _padding = EdgeInsets.symmetric(
    horizontal: Tokens.spSm,
    vertical: Tokens.spXs,
  );

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: _layout,
        child: const SizedBox.expand(),
      ),
    ),
  );

  /// Measure actual scaled text then clamp to the route viewport, not bar width.
  Widget _layout(BuildContext context, OverlayChildLayoutInfo info) {
    if (!_eligible) return const SizedBox.shrink();
    final available = (info.overlaySize.width - Tokens.spMd * 2).clamp(
      1.0,
      double.infinity,
    );
    // Measurement must include inherited font family/line height, exactly as
    // Text does; measuring an unmerged style underestimates the painted box.
    final style = DefaultTextStyle.of(context).style.merge(_style);
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: available - _padding.horizontal);
    final width = (painter.width + _padding.horizontal).clamp(1.0, available);
    final height = painter.height + _padding.vertical;
    painter.dispose();
    // Transforming the local point keeps the preview attached through resize,
    // retained layout changes and route-local fullscreen controls recreation.
    final anchor = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(widget.fraction * widget.barWidth, 0),
    );
    final left = (anchor.dx - width / 2).clamp(
      Tokens.spMd,
      info.overlaySize.width - width - Tokens.spMd,
    );
    final top = (anchor.dy - height - Tokens.spXs).clamp(
      Tokens.spXs,
      (info.overlaySize.height - height - Tokens.spXs).clamp(
        Tokens.spXs,
        double.infinity,
      ),
    );
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: widget.opacity,
          child: SecondarySurface(
            padding: _padding,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: _style,
            ),
          ),
        ),
      ),
    );
  }
}
