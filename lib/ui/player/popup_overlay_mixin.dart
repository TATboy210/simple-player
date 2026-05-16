import 'package:flutter/material.dart';

/// Popup overlay lifecycle base class using modern `OverlayPortalController`.
///
/// Encapsulates: OverlayPortalController, LayerLink, AnimationController,
/// opacity/scale animations, open/close/toggle logic, and external
/// close-notifier coordination.
///
/// Usage:
/// ```dart
/// class _MyState extends PopupOverlayState<MyWidget> {
///   @override
///   Widget build(BuildContext context) {
///     return CompositedTransformTarget(
///       link: layerLink,
///       child: OverlayPortal(
///         controller: popupController,
///         overlayChildBuilder: _buildPopup,
///         child: _buildButton(),
///       ),
///     );
///   }
/// }
/// ```
abstract class PopupOverlayState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Configuration — override in concrete State
  // ---------------------------------------------------------------------------

  Duration get popupDuration => const Duration(milliseconds: 250);
  Duration get popupReverseDuration => const Duration(milliseconds: 180);
  Curve get popupCurve => Curves.easeOutCubic;
  Curve get popupReverseCurve => Curves.easeIn;
  double? get popupScaleBegin => 0.85;

  /// Optional notifier for coordinating close requests from parent.
  ValueNotifier<int>? get popupCloseNotifier => null;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final popupController = OverlayPortalController();
  final layerLink = LayerLink();
  final ValueNotifier<bool> popupShowing = ValueNotifier(false);

  late final AnimationController popupAnim;
  late final Animation<double> popupOpacity;
  late final Animation<double>? popupScale;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    popupAnim = AnimationController(
      vsync: this,
      duration: popupDuration,
      reverseDuration: popupReverseDuration,
      value: 0,
    );
    popupOpacity = CurvedAnimation(
      parent: popupAnim,
      curve: popupCurve,
      reverseCurve: popupReverseCurve,
    );
    final begin = popupScaleBegin;
    popupScale = begin != null
        ? Tween<double>(begin: begin, end: 1.0).animate(
            CurvedAnimation(
              parent: popupAnim,
              curve: popupCurve,
              reverseCurve: popupReverseCurve,
            ),
          )
        : null;
    popupCloseNotifier?.addListener(_onCloseRequested);
  }

  @override
  void dispose() {
    popupCloseNotifier?.removeListener(_onCloseRequested);
    popupAnim.stop();
    if (popupController.isShowing) popupController.hide();
    popupShowing.dispose();
    popupAnim.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  bool get isPopupShowing => popupController.isShowing;

  void togglePopup() {
    if (isPopupShowing) {
      closePopup();
    } else {
      openPopup();
    }
  }

  void openPopup() {
    popupAnim.stop();
    popupController.show();
    popupShowing.value = true;
    popupAnim.forward(from: 0.0);
  }

  void closePopup() {
    popupAnim.reverse().then((_) {
      if (mounted && popupController.isShowing) {
        popupController.hide();
      }
      if (mounted) popupShowing.value = popupController.isShowing;
    });
  }

  void closePopupImmediate() {
    popupAnim.stop();
    if (popupController.isShowing) popupController.hide();
    if (mounted) popupShowing.value = false;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _onCloseRequested() {
    if (popupController.isShowing) closePopupImmediate();
  }
}
