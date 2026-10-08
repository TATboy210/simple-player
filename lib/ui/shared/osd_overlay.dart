import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'osd_message.dart';
import 'osd_service.dart';
import 'secondary_surface.dart';

// Narrow compatibility exports for existing status callers; not a general barrel.
export 'osd_message.dart';
export 'osd_service.dart';

/// 反馈展示层 — route-local opacity only; never resets the shared service.
class OsdOverlay extends StatefulWidget {
  const OsdOverlay({super.key, this.resizing, this.service});

  /// Compatibility seam: resizing intentionally cannot freeze feedback or time.
  final ValueListenable<bool>? resizing;

  /// Borrowed service; the caller retains disposal and timer ownership.
  final OsdService? service;

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _opacity;
  OsdMessage? _payload;
  int _generation = 0;
  bool _isListening = false;
  bool _isActive = false;
  OsdService get _service => widget.service ?? OsdService.I;

  @override
  void initState() {
    super.initState();
    _opacity =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: Tokens.osdFadeDurationMs),
          )
          ..addStatusListener(_onAnimationStatus)
          ..addListener(_onOpacityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isActive = TickerMode.valuesOf(context).enabled;
    if (_isActive) {
      _attach();
      _sync();
    } else {
      _detach();
      _opacity?.stop();
    }
  }

  @override
  void didUpdateWidget(covariant OsdOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      if (_isListening) {
        (oldWidget.service ?? OsdService.I).snapshot.removeListener(_sync);
        _isListening = false;
      }
      if (_isActive) {
        _attach();
        _sync();
      }
    }
  }

  /// Only an active route owns a presentation listener/ticker.
  void _attach() {
    if (_isListening) return;
    _service.snapshot.addListener(_sync);
    _isListening = true;
  }

  void _detach() {
    if (!_isListening) return;
    _service.snapshot.removeListener(_sync);
    _isListening = false;
  }

  /// Payload changes immediately; a new arrival reverses from current opacity.
  void _sync() {
    if (!_isActive || !mounted) return;
    final state = _service.snapshot.value;
    _generation = state.generation;
    final incoming = state.current?.message;
    setState(() {
      if (incoming != null) _payload = incoming;
    });
    final controller = _opacity;
    if (controller == null) return;
    if (incoming == null) {
      controller.animateBack(
        0,
        duration: controller.duration,
        curve: Curves.easeOut,
      );
    } else {
      controller.animateTo(
        1,
        duration: controller.duration,
        curve: Curves.easeOut,
      );
    }
    // A hide before the first visible frame has no fade to complete.
    if (incoming == null && controller.isDismissed) _clearExitedPayload();
  }

  /// animateBack may already have reverse status when its value reaches zero.
  /// Check the value too so completion cleanup never depends on status ordering.
  void _onOpacityChanged() {
    if (_opacity?.value == 0) _clearExitedPayload();
  }

  /// Snapshot generation blocks stale fade completion from erasing new content.
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _clearExitedPayload();
  }

  void _clearExitedPayload() {
    final state = _service.snapshot.value;
    if (!_isActive ||
        !mounted ||
        state.generation != _generation ||
        state.isVisible ||
        _payload == null) {
      return;
    }
    setState(() => _payload = null);
  }

  @override
  void deactivate() {
    _isActive = false;
    _detach();
    _opacity?.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _detach();
    _opacity?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final opacity = _opacity;
    if (payload == null || opacity == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: FadeTransition(
        opacity: opacity,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: RepaintBoundary(child: _OsdBubble(message: payload)),
        ),
      ),
    );
  }
}

/// 完整短摘要气泡 — wraps at the normal text scale; no scrolling or shrinking.
/// Callers supply bounded summaries; diagnostic detail belongs in the card/log.
class _OsdBubble extends StatelessWidget {
  const _OsdBubble({required this.message});
  final OsdMessage message;

  @override
  Widget build(BuildContext context) => SecondarySurface(
    // IgnorePointer makes a scroll viewport inaccessible; render all summary
    // lines directly, with icon/progress included in the bubble's natural height.
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.icon != null) ...[
              Icon(
                message.icon,
                size: Tokens.osdIconSize,
                color: Tokens.textPrimary,
              ),
              const SizedBox(width: Tokens.spSm),
            ],
            Flexible(
              child: Text(
                message.text,
                softWrap: true,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontTitle,
                  fontWeight: Tokens.weightRegular,
                  fontFeatures: [Tokens.tabularFigures],
                ),
              ),
            ),
          ],
        ),
        if (message.progress case final progress?) ...[
          const SizedBox(height: Tokens.spSm),
          SizedBox(
            width: Tokens.osdProgressWidth,
            height: Tokens.osdProgressHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.progressBarRadius),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: Tokens.osdTrackColor,
                valueColor: const AlwaysStoppedAnimation(Tokens.accent),
                minHeight: Tokens.osdProgressHeight,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
