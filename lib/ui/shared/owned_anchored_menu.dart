import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../player/workspace_menu_session.dart';
import '../theme/tokens.dart';
import 'secondary_surface.dart';
import 'secondary_surface_visibility.dart';

/// 不可变动作项 — checked is informational, never a disabled radio choice.
class OwnedMenuEntry<T> {
  const OwnedMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.isEnabled = true,
    this.isChecked = false,
    this.isDestructive = false,
  });
  final T value;
  final String label;
  final IconData? icon;
  final bool isEnabled;
  final bool isChecked;
  final bool isDestructive;
}

/// 菜单结果 — null future result denotes cancellation, not a selected null value.
class OwnedMenuSelection<T> {
  const OwnedMenuSelection(this.value);
  final T value;
}

/// 精确路由句柄 — borrowed session/visibility/focus are never disposed here.
class OwnedMenuHandle<T> {
  OwnedMenuHandle._(this.route, this.token, this.result, this.cancel);
  final PopupRoute<OwnedMenuSelection<T>> route;
  final Object token;
  final Future<OwnedMenuSelection<T>?> result;
  final VoidCallback cancel;
}

/// 项目自有菜单入口 — bind the route at creation, never infer latest popup.
class OwnedAnchoredMenu {
  OwnedAnchoredMenu._();

  /// Open at a live button rectangle or a captured GLOBAL context-menu point.
  /// Key openers must call session.latchEvent(event) before this method.
  /// [isOwnerValid] optionally validates captured logical identity at focus
  /// return, in addition to the default mounted/visible/current-route guards.
  static OwnedMenuHandle<T> open<T>(
    BuildContext trigger, {
    required Object owner,
    required List<OwnedMenuEntry<T>> entries,
    WorkspaceMenuSession? session,
    bool useWorkspaceScope = true,
    Offset? position,
    T? initialValue,
    FocusNode? triggerFocus,
    bool Function()? isOwnerValid,
    ValueNotifier<bool>? visibility,
    String? mediaIdentity,
    VoidCallback? onEscape,
  }) {
    final scope = useWorkspaceScope
        ? WorkspaceMenuScope.maybeOf(trigger)
        : null;
    final menus = session ?? scope?.session ?? WorkspaceMenuSession();
    final ownsSession = session == null && scope == null;
    final signal = visibility ?? SecondarySurfaceVisibility.read(trigger);
    final sourceRoute = ModalRoute.of(trigger);
    final navigator = Navigator.of(trigger, rootNavigator: true);
    final route = _OwnedMenuRoute<T>(
      trigger: trigger,
      position: position,
      entries: List.unmodifiable(entries),
      initialValue: initialValue,
      session: menus,
    );
    final token = menus.open(
      owner: owner,
      mediaIdentity: mediaIdentity,
      cancel: () => _remove(route, navigator),
      isCurrent: () =>
          route.isCurrent && trigger.mounted && signal?.value != false,
      canGuardLatchedEvent: () =>
          route.isCurrent || sourceRoute?.isCurrent == true,
      onEscape: onEscape ?? scope?.onEscape,
    );
    route.token = token;
    void cancel() {
      if (menus.owns(token)) menus.cancelOwner(owner);
    }

    // open() publishes synchronously: a listener can cancel/dispose/replace us
    // before push. An inactive route cannot be removed by that cancellation.
    if (!menus.owns(token) || !trigger.mounted || signal?.value == false) {
      if (menus.owns(token)) menus.finish(token);
      // No Navigator owns this route yet; complete and dispose it exactly here.
      // Never attach visibility listeners or restore focus for a rejected open.
      route.rejectBeforePush();
      if (ownsSession) menus.dispose();
      return OwnedMenuHandle._(route, token, route.popped, cancel);
    }
    final result = navigator.push(route);
    final handle = OwnedMenuHandle._(route, token, result, cancel);
    _trackCompletion(
      handle,
      menus,
      trigger,
      sourceRoute,
      triggerFocus,
      signal,
      ownsSession,
      isOwnerValid,
    );
    return handle;
  }

  /// Attach the borrowed visibility listener and remove it at exact completion.
  static void _trackCompletion<T>(
    OwnedMenuHandle<T> handle,
    WorkspaceMenuSession menus,
    BuildContext trigger,
    ModalRoute<Object?>? source,
    FocusNode? focus,
    ValueNotifier<bool>? signal,
    bool ownsSession,
    bool Function()? isOwnerValid,
  ) {
    void visibilityChanged() {
      if (signal?.value == false) handle.cancel();
    }

    signal?.addListener(visibilityChanged);
    visibilityChanged();
    unawaited(
      handle.result.then((_) {
        signal?.removeListener(visibilityChanged);
        menus.finish(handle.token);
        // Replacement/top dialog/hidden owner must never lose its actual focus.
        if (menus.mayRestoreFocus(handle.token) &&
            trigger.mounted &&
            signal?.value != false &&
            source?.isCurrent == true &&
            (isOwnerValid?.call() ?? true) &&
            focus?.context != null &&
            focus?.canRequestFocus == true) {
          focus?.requestFocus();
        }
        if (ownsSession) menus.dispose();
      }),
    );
  }

  /// Invalidate session synchronously; defer only Navigator mutation in build.
  static void _remove<T>(_OwnedMenuRoute<T> route, NavigatorState navigator) {
    void remove() {
      if (route.isActive) navigator.removeRoute(route);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => remove());
    } else {
      remove();
    }
  }
}

class _OwnedMenuRoute<T> extends PopupRoute<OwnedMenuSelection<T>> {
  _OwnedMenuRoute({
    required this.trigger,
    required this.position,
    required this.entries,
    required this.initialValue,
    required this.session,
  });
  final T? initialValue;
  final BuildContext trigger;
  final Offset? position;
  final List<OwnedMenuEntry<T>> entries;
  final WorkspaceMenuSession session;
  Object? token;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Dismiss menu';
  @override
  Duration get transitionDuration => Duration.zero;

  /// Rejected routes have no Navigator owner; release them without installing.
  void rejectBeforePush() {
    didComplete(null);
    dispose();
  }

  /// All anchor coordinates are converted into THIS navigator overlay space.
  Rect? anchor() {
    final overlay = navigator?.overlay?.context.findRenderObject();
    if (!trigger.mounted) return null;
    final box = trigger.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return null;
    if (position case final point?) {
      return Rect.fromLTWH(
        overlay.globalToLocal(point).dx,
        overlay.globalToLocal(point).dy,
        0,
        0,
      );
    }
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final origin = overlay.globalToLocal(box.localToGlobal(Offset.zero));
    return origin & box.size;
  }

  /// Guard row actions against owner hide or exact-route teardown races.
  void select(OwnedMenuEntry<T> entry) {
    final currentToken = token;
    if (!entry.isEnabled ||
        currentToken == null ||
        !session.owns(currentToken) ||
        !session.isOwnedMenuTopmost) {
      return;
    }
    navigator?.pop(OwnedMenuSelection(entry.value));
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _MenuBody<T>(route: this);
}

class _MenuBody<T> extends StatefulWidget {
  const _MenuBody({required this.route});
  final _OwnedMenuRoute<T> route;
  @override
  State<_MenuBody<T>> createState() => _MenuBodyState<T>();
}

class _MenuBodyState<T> extends State<_MenuBody<T>> {
  final List<FocusNode> _rows = [];
  Rect? _anchor;
  int _selected = -1;

  @override
  void initState() {
    super.initState();
    _rows.addAll(
      widget.route.entries.map(
        (entry) => FocusNode(
          debugLabel: 'owned-menu-${entry.label}',
          canRequestFocus: entry.isEnabled,
          skipTraversal: !entry.isEnabled,
        ),
      ),
    );
    // Selectors start at their explicit current value; action menus start first.
    final initial = widget.route.entries.indexWhere(
      (entry) => entry.isEnabled && entry.value == widget.route.initialValue,
    );
    _selected = initial >= 0
        ? initial
        : widget.route.entries.indexWhere((entry) => entry.isEnabled);
    _anchor = widget.route.anchor();
    // Only an open live-button menu observes geometry; cached children stay intact.
    WidgetsBinding.instance.addPostFrameCallback(_checkAnchor);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelected());
  }

  /// Observe movement/scroll/unmount, not fixed row-size or character estimates.
  void _checkAnchor(Duration elapsed) {
    if (!mounted) return;
    final anchor = widget.route.anchor();
    if (anchor == null) {
      final token = widget.route.token;
      if (token != null && widget.route.session.owns(token)) {
        widget.route.session.cancel();
      }
    } else if (anchor != _anchor) {
      setState(() => _anchor = anchor);
    }
    // Observe only frames produced by the application; do not force idle frames.
    WidgetsBinding.instance.addPostFrameCallback(_checkAnchor);
  }

  void _focusSelected() {
    if (!mounted || !widget.route.session.isOwnedMenuTopmost || _selected < 0) {
      return;
    }
    _rows[_selected].requestFocus();
    final rowContext = _rows[_selected].context;
    if (rowContext != null) {
      unawaited(Scrollable.ensureVisible(rowContext));
    }
  }

  /// Wrap traversal over enabled ACTIONS, including currently checked sort keys.
  void _move(int delta) {
    final count = _rows.length;
    if (count == 0) return;
    for (var step = 1; step <= count; step++) {
      final next = (_selected + delta * step) % count;
      if (widget.route.entries[next].isEnabled) {
        setState(() => _selected = next);
        _focusSelected();
        return;
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!widget.route.session.isOwnedMenuTopmost) return KeyEventResult.ignored;
    widget.route.session.latchEvent(event);
    // 焦点陷阱：Tab 交给默认遍历会越出菜单 route 落到播放器（↑↓ 变 seek）。
    // Focus trap: default traversal lets Tab escape the menu route and leak
    // keys to the player; intercept Tab/Shift+Tab and wrap within enabled
    // rows via _move (末行 Tab 回首行). Repeat/Up swallow without moving,
    // so the default traversal policy never takes over.
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (event is KeyDownEvent) {
        // Shift 状态取自 HardwareKeyboard 全局按压集，KeyEvent 无此 getter。
        _move(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      }
      return KeyEventResult.handled; // Down moves; Repeat/Up swallow only.
    }
    final key = event.logicalKey;
    // 长按连续移动是桌面菜单惯例:KeyRepeat 只放行 ↑/↓ 送入 _move;
    // 激活键(Enter/Space/numpadEnter)与其他键的按住重复一律在此吞掉,
    // 永远到不了 select(),按住激活键不可能连发选择(T-261009-fiw-01 缓解)。
    // Held-key repeat: only ↑/↓ repeats pass the gate into _move; all other
    // repeats (activation keys included) are swallowed here and can never
    // reach select(), so holding a key cannot reselect (T-261009-fiw-01).
    final isArrowRepeat =
        event is KeyRepeatEvent &&
        (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp);
    if (event is! KeyDownEvent && !isArrowRepeat) {
      return KeyEventResult.handled; // 未放行事件一律吞掉,不泄漏到播放器。
    }
    if (key == LogicalKeyboardKey.arrowDown) _move(1);
    if (key == LogicalKeyboardKey.arrowUp) _move(-1);
    if (_selected >= 0 &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      widget.route.select(widget.route.entries[_selected]);
    }
    return KeyEventResult.handled; // Left/right cannot leak to seek.
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => CustomSingleChildLayout(
      delegate: _AnchorLayout(_anchor ?? Rect.zero),
      child: Material(
        color: Colors.transparent,
        child: SecondarySurface(
          padding: const EdgeInsets.all(Tokens.spSm),
          child: SingleChildScrollView(
            child: IntrinsicWidth(
              child: FocusTraversalGroup(
                // 显式遍历域：任何残余遍历（无障碍/程序化 nextFocus）都在
                // 菜单行内按 Column 顺序进行，绝不越出菜单 route。
                // Explicit traversal scope: any residual traversal (a11y or
                // programmatic nextFocus) stays ordered within the menu rows.
                child: Focus(
                  onKeyEvent: _key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (var i = 0; i < _rows.length; i++) _row(i)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Only actual focus paints selection; checked state never claims focus.
  bool _isFocused(int index) =>
      _selected == index && _rows[index].hasPrimaryFocus;

  Widget _row(int index) {
    final entry = widget.route.entries[index];
    return Focus(
      focusNode: _rows[index],
      onFocusChange: (focused) {
        if (!mounted) return;
        // Repaint both focus gain AND loss; checked/hover are separate states.
        setState(() {
          if (focused) _selected = index;
        });
      },
      child: Semantics(
        button: true,
        enabled: entry.isEnabled,
        checked: entry.isChecked,
        child: InkWell(
          canRequestFocus: false,
          mouseCursor: entry.isEnabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          hoverColor: Tokens.bgHover,
          onTap: entry.isEnabled ? () => widget.route.select(entry) : null,
          child: _rowSurface(index, entry),
        ),
      ),
    );
  }

  /// Token-based keyboard paint, independent of checked and hover feedback.
  Widget _rowSurface(int index, OwnedMenuEntry<T> entry) => DecoratedBox(
    // Paint the real outer Focus node, without another InkWell Tab stop.
    // A solid background identifies keyboard focus without an accent outline.
    decoration: BoxDecoration(
      color: _isFocused(index) ? Tokens.bgElevated : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
    ),
    child: Padding(
      padding: const EdgeInsets.all(Tokens.spSm),
      child: Row(
        children: [
          if (entry.icon case final icon?) ...[
            Icon(
              icon,
              size: Tokens.fontBody,
              color: entry.isDestructive ? Tokens.danger : Tokens.textSecondary,
            ),
            const SizedBox(width: Tokens.spSm),
          ],
          Flexible(
            child: Text(
              entry.label,
              softWrap: true,
              style: TextStyle(
                fontSize: Tokens.fontCaption,
                color: entry.isEnabled
                    ? Tokens.textPrimary
                    : Tokens.textSecondary,
              ),
            ),
          ),
          if (entry.isChecked) const Icon(Icons.check, size: Tokens.fontBody),
        ],
      ),
    ),
  );
}

/// Real child measurement precedes clamping; tiny windows never invert bounds.
class _AnchorLayout extends SingleChildLayoutDelegate {
  _AnchorLayout(this.anchor);
  final Rect anchor;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - Tokens.spSm * 2),
        maxHeight: math.max(0, constraints.maxHeight - Tokens.spSm * 2),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = math.max(0.0, size.width - childSize.width);
    final maxY = math.max(0.0, size.height - childSize.height);
    final insetX = math.min(Tokens.spSm, maxX);
    final insetY = math.min(Tokens.spSm, maxY);
    return Offset(
      anchor.left.clamp(insetX, math.max(insetX, maxX - insetX)),
      anchor.bottom.clamp(insetY, math.max(insetY, maxY - insetY)),
    );
  }

  @override
  bool shouldRelayout(_AnchorLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
}
