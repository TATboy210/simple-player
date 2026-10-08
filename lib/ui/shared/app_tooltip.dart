import 'dart:async';

import 'package:flutter/material.dart';

import '../player/workspace_menu_session.dart';
import '../theme/tokens.dart';
import 'secondary_surface.dart';
import 'secondary_surface_visibility.dart';

/// 播放器提示 — observes actual control focus without adding a Tab stop.
/// Owns one one-shot delay and one pointer-transparent entry; sources are borrowed.
class AppTooltip extends StatefulWidget {
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.focusNode,
    this.waitDuration = const Duration(milliseconds: Tokens.tooltipDelayShort),
  });

  final String? message;
  final Widget child;

  /// Existing control node, never attached or disposed by this wrapper.
  /// Without one, observe the genuinely focused descendant (e.g. InkWell).
  final FocusNode? focusNode;
  final Duration waitDuration;

  @override
  State<AppTooltip> createState() => _AppTooltipState();
}

class _AppTooltipState extends State<AppTooltip> {
  Timer? _delay;
  OverlayEntry? _entry;
  ValueNotifier<bool>? _owner;
  ValueNotifier<bool>? _menus;
  bool _hovered = false;
  bool _eligible = false;
  bool _active = true;
  bool _implicitFocus = false;
  bool _focusSyncQueued = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // FocusManager is event-driven and covers controls whose node lives below us.
    FocusManager.instance.addListener(_sync);
    widget.focusNode?.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = SecondarySurfaceVisibility.maybeOf(context);
    final menus =
        SecondarySurfaceMenuPolicy.maybeOf(context) ??
        WorkspaceMenuScope.maybeOf(context)?.session;
    if (!identical(owner, _owner) || !identical(menus, _menus)) {
      _owner?.removeListener(_sync);
      _menus?.removeListener(_sync);
      _owner = owner;
      _menus = menus;
      _owner?.addListener(_sync);
      _menus?.addListener(_sync);
      _cancel();
      _eligible = false;
    }
    _sync();
  }

  @override
  void didUpdateWidget(AppTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode?.removeListener(_sync);
      widget.focusNode?.addListener(_sync);
    }
    if (oldWidget.message != widget.message ||
        oldWidget.waitDuration != widget.waitDuration ||
        !identical(oldWidget.focusNode, widget.focusNode)) {
      _cancel();
      _eligible = false;
    }
    _sync();
  }

  /// Only the control subtree may supply implicit focus, not the player root.
  bool get _hasControlFocus {
    final explicit = widget.focusNode;
    if (explicit != null) return explicit.hasFocus;
    _queueImplicitFocusSync();
    return _implicitFocus;
  }

  /// Search our live subtree after synchronous build/reparent has completed.
  /// Never walk a primaryFocus context: it may still be deactivated until the
  /// FocusManager commits its pending change. No focus node or Tab stop is added.
  void _queueImplicitFocusSync() {
    if (_focusSyncQueued) return;
    _focusSyncQueued = true;
    scheduleMicrotask(() {
      _focusSyncQueued = false;
      if (!mounted || !_active) return;
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      var inside = identical(focusedContext, context);
      void visit(Element element) {
        if (inside) return;
        inside = identical(element, focusedContext);
        if (!inside) element.visitChildElements(visit);
      }

      if (focusedContext != null) context.visitChildElements(visit);
      if (inside == _implicitFocus) return;
      _implicitFocus = inside;
      _sync();
    });
  }

  /// Eligibility is OR of hover/focus; losing only one must not restart its clock.
  void _sync() {
    final eligible =
        _active &&
        mounted &&
        widget.message?.trim().isNotEmpty == true &&
        _owner?.value != false &&
        _menus?.value != true &&
        (_hovered || _hasControlFocus);
    if (eligible == _eligible) return;
    _eligible = eligible;
    _cancel();
    if (!eligible) return;
    final generation = _generation;
    _delay = Timer(widget.waitDuration, () {
      _delay = null;
      if (!mounted || !_active || !_eligible || generation != _generation) {
        return;
      }
      _show();
    });
  }

  /// Exact removal is safe during build: OverlayEntry.remove defers dirty marking.
  void _cancel() {
    _generation++;
    _delay?.cancel();
    _delay = null;
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  /// Insert only this tooltip; no global dismiss or focus request is performed.
  void _show() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final text = widget.message?.trim() ?? '';
    final entry = OverlayEntry(builder: (_) => _buildEntry(text));
    _entry = entry;
    overlay.insert(entry);
  }

  /// 完整短标签 — reachable producers supply finite localized actions/brands.
  /// Measure and wrap that corpus naturally; diagnostic reports belong in the
  /// error card, not an inaccessible scroll view under this IgnorePointer.
  Widget _buildEntry(String text) => Positioned.fill(
    child: IgnorePointer(
      child: ExcludeFocus(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Removed entries may get one final layout before Overlay's deferred
            // repaint; never query an inactive owner from that outgoing layout.
            if (!_active || !mounted || _entry == null) {
              return const SizedBox.shrink();
            }
            final render = this.context.findRenderObject();
            final overlayRender = Overlay.of(this.context).context
                .findRenderObject();
            final anchor = render is RenderBox && overlayRender is RenderBox
                ? render.localToGlobal(Offset.zero, ancestor: overlayRender) &
                      render.size
                : Rect.zero;
            return CustomSingleChildLayout(
              delegate: _TooltipLayout(anchor),
              child: SecondarySurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spMd,
                  vertical: Tokens.spSm,
                ),
                child: Text(
                  text,
                  softWrap: true,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                    fontFamily: Tokens.fontFamily,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  @override
  void deactivate() {
    _active = false;
    _eligible = false;
    _implicitFocus = false;
    _hovered = false;
    _cancel();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _sync();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_sync);
    widget.focusNode?.removeListener(_sync);
    _owner?.removeListener(_sync);
    _menus?.removeListener(_sync);
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) {
      _hovered = true;
      _sync();
    },
    onExit: (_) {
      _hovered = false;
      _sync();
    },
    // Preserve Tooltip metadata for existing byTooltip finders without enabling
    // Flutter's autonomous hover/touch controller alongside our exact owner.
    child: TooltipVisibility(
      visible: false,
      child: Tooltip(
        message: widget.message ?? '',
        excludeFromSemantics: true,
        child: Semantics(tooltip: widget.message, child: widget.child),
      ),
    ),
  );
}

/// Measure before placing: no width estimates, truncation or font shrinking.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: (constraints.maxWidth - Tokens.spMd * 2).clamp(
          0,
          double.infinity,
        ),
        maxHeight: (constraints.maxHeight - Tokens.spMd * 2).clamp(
          0,
          double.infinity,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (anchor.center.dx - childSize.width / 2).clamp(
      Tokens.spMd,
      (size.width - childSize.width - Tokens.spMd).clamp(
        Tokens.spMd,
        double.infinity,
      ),
    );
    final below = anchor.bottom + Tokens.spSm;
    final y =
        (below + childSize.height <= size.height - Tokens.spMd
                ? below
                : anchor.top - Tokens.spSm - childSize.height)
            .clamp(
              Tokens.spMd,
              (size.height - childSize.height - Tokens.spMd).clamp(
                Tokens.spMd,
                double.infinity,
              ),
            );
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
}
