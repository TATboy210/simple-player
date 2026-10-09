import 'package:flutter/material.dart';

/// 可见 owner 的窄适配器 — compose live parent/layer eligibility outside caches.
/// Owns only its output notifier; all source notifiers remain borrowed.
class SecondarySurfaceOwner extends StatefulWidget {
  const SecondarySurfaceOwner({
    super.key,
    required this.visible,
    required this.child,
    this.eligibility,
  });

  final bool visible;
  final ValueNotifier<bool>? eligibility;
  final Widget child;

  @override
  State<SecondarySurfaceOwner> createState() => _SecondarySurfaceOwnerState();
}

class _SecondarySurfaceOwnerState extends State<SecondarySurfaceOwner> {
  final ValueNotifier<bool> _visible = ValueNotifier(false);
  ValueNotifier<bool>? _parent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = SecondarySurfaceVisibility.maybeOf(context);
    if (!identical(parent, _parent)) {
      _parent?.removeListener(_sync);
      _parent = parent;
      _parent?.addListener(_sync);
    }
    _sync();
  }

  @override
  void initState() {
    super.initState();
    widget.eligibility?.addListener(_sync);
  }

  @override
  void didUpdateWidget(SecondarySurfaceOwner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.eligibility, widget.eligibility)) {
      oldWidget.eligibility?.removeListener(_sync);
      widget.eligibility?.addListener(_sync);
    }
    _sync();
  }

  /// Publish synchronously so route actions cannot race hidden cached owners.
  void _sync() {
    _visible.value =
        widget.visible &&
        _parent?.value != false &&
        widget.eligibility?.value != false;
  }

  @override
  void dispose() {
    _parent?.removeListener(_sync);
    widget.eligibility?.removeListener(_sync);
    _visible.value =
        false; // Exact menu cancels before its borrowed source dies.
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SecondarySurfaceVisibility(visibility: _visible, child: widget.child);
}

/// 缓存次级表面的实时资格 — keep the notifier outside retained child caches.
/// Owners publish visibility (including L0/L1 eligibility); consumers borrow it.
class SecondarySurfaceVisibility
    extends InheritedNotifier<ValueNotifier<bool>> {
  const SecondarySurfaceVisibility({
    super.key,
    required ValueNotifier<bool> visibility,
    required super.child,
  }) : super(notifier: visibility);

  /// Subscribe to the nearest owner without replacing its cached child.
  static ValueNotifier<bool>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SecondarySurfaceVisibility>()
      ?.notifier;

  /// Read the live signal for callbacks where inherited dependencies are illegal.
  static ValueNotifier<bool>? read(BuildContext context) => context
      .getInheritedWidgetOfExactType<SecondarySurfaceVisibility>()
      ?.notifier;
}
