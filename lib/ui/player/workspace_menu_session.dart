import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'modal_hold_observer.dart';
import '../shared/secondary_surface_visibility.dart';

/// 附属菜单所有权 — 非菜单对话框不参与此会话。
/// Owns one cancellable menu and pairs its early-key handler with its lifetime.
class WorkspaceMenuSession extends ValueNotifier<bool> {
  WorkspaceMenuSession() : super(false);
  Object? _token;
  VoidCallback? _cancel;
  bool Function()? _isCurrent;
  VoidCallback? _onEscape;
  String? _mediaIdentity;
  Object? _owner;
  bool _disposed = false;
  bool _hasKeyHook = false;

  /// Compatibility access for synchronous facade callbacks, not popup guessing.
  Object? get currentToken => _token;

  /// Rebind a legacy callback's exact token to the route just created by facade.
  bool bindRoute(
    Object token,
    Route<Object?> route,
    ModalRoute<Object?>? source,
  ) {
    if (!owns(token)) return false;
    _isCurrent = () => route.isCurrent;
    _canGuardLatchedEvent = () => route.isCurrent || source?.isCurrent == true;
    return true;
  }

  final Map<KeyEvent, bool Function()> _ownedEvents = Map.identity();
  bool Function()? _canGuardLatchedEvent;
  Object? _lastToken;

  /// Completion may restore focus after cancellation, but never after replacement.
  bool mayRestoreFocus(Object token) =>
      !_disposed && _token == null && identical(token, _lastToken);

  /// Synchronous query; notifier publication may intentionally wait for build.
  bool get isOwnedMenuTopmost => !_disposed && _isCurrent?.call() == true;

  /// Exact token authority for row actions and stale route completion guards.
  bool owns(Object token) => !_disposed && identical(token, _token);

  /// Retain event identity through every synchronous HardwareKeyboard/Focus path.
  /// Foreign top dialogs always yield, including a latch from an underlying menu.
  bool guardsPlayerEvent(KeyEvent event) {
    if (_token != null && !isOwnedMenuTopmost) return false;
    final eligible = _ownedEvents[event];
    if (eligible != null) return eligible();
    if (!isOwnedMenuTopmost) return false;
    latchEvent(event);
    return true;
  }

  /// Call BEFORE opening/canceling/selecting within a key handler.
  /// Microtask cleanup preserves suppression even after synchronous route removal.
  void latchEvent(KeyEvent event) {
    if (!_ownedEvents.containsKey(event)) {
      _ownedEvents[event] = _canGuardLatchedEvent ?? () => true;
      scheduleMicrotask(() => _ownedEvents.remove(event));
    }
  }

  /// Build-time owner removal invalidates synchronously, but UI/route mutation
  /// waits until the frame ends. Publish the current token, never stale false.
  void _publish() {
    if (_disposed) return;
    _afterBuild(() {
      if (!_disposed) value = _token != null;
    });
  }

  /// Route/overlay teardown must not mark an ancestor dirty during child build.
  static void _afterBuild(VoidCallback action) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    } else {
      action();
    }
  }

  /// 打开指定 owner 的可取消菜单，返回匹配完成回调的代次。
  Object open({
    required Object owner,
    required VoidCallback cancel,
    required bool Function() isCurrent,
    bool Function()? canGuardLatchedEvent,
    String? mediaIdentity,
    VoidCallback? onEscape,
  }) {
    final token = Object();
    if (_disposed) {
      _afterBuild(cancel);
      return token;
    }
    this.cancel();
    _token = token;
    _lastToken = token;
    _canGuardLatchedEvent = canGuardLatchedEvent;
    _owner = owner;
    _cancel = cancel;
    _isCurrent = isCurrent;
    _onEscape = onEscape;
    _mediaIdentity = mediaIdentity;
    if (!_hasKeyHook) {
      FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
      _hasKeyHook = true;
    }
    _publish();
    return token;
  }

  /// 仅结束匹配代次，避免旧完成回调清理新菜单。
  bool finish(Object token) {
    if (!identical(token, _token)) return false;
    if (_hasKeyHook) {
      FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
      _hasKeyHook = false;
    }
    _token = null;
    _owner = null;
    _cancel = null;
    _isCurrent = null;
    _canGuardLatchedEvent = null;
    _onEscape = null;
    _mediaIdentity = null;
    _publish();
    return true;
  }

  /// 先清理持有与键盘钩子，再移除精确菜单，避免完成回调重入。
  bool cancel() {
    final token = _token;
    if (token == null) return false;
    final close = _cancel;
    finish(token);
    // Capture the old teardown before deferring; it must not cancel a new menu.
    if (close != null) _afterBuild(close);
    return true;
  }

  /// owner 卸载时取消自己的菜单，不影响已被另一入口替换的菜单。
  void cancelOwner(Object owner) {
    if (identical(_owner, owner)) cancel();
  }

  /// 仅清理绑定旧媒体身份的菜单。
  void mediaChanged(String identity) {
    if (_mediaIdentity != null && _mediaIdentity != identity) cancel();
  }

  /// 菜单路由自己的 DismissIntent 之前消费 ESC；其他顶层对话框不受影响。
  KeyEventResult _handleKey(KeyEvent event) {
    if (!isOwnedMenuTopmost) return KeyEventResult.ignored;
    latchEvent(event);
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored; // Navigation belongs to the actual route.
    }
    if (event is KeyDownEvent) _onEscape?.call();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    super.dispose();
  }
}

/// route 本地菜单上下文 — 共享会话，退出回调仍绑定当前 controls 实例。
class WorkspaceMenuScope extends InheritedWidget {
  const WorkspaceMenuScope({
    super.key,
    required this.session,
    required this.onEscape,
    required super.child,
  });
  final WorkspaceMenuSession session;
  final VoidCallback onEscape;

  /// 最近祖先 scope；独立组件测试可无 scope，沿用原始菜单行为。
  static WorkspaceMenuScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WorkspaceMenuScope>();

  /// showMenu/DropdownButton push 后立即绑定观察者记录的精确 PopupRoute。
  void ownLatestRoute(
    BuildContext trigger,
    Object owner, {
    FocusNode? triggerFocus,
  }) {
    final route = ModalHoldObserver.latestPopup;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isCurrent) return;
    final sourceRoute = ModalRoute.of(trigger);
    final focus = triggerFocus;
    final visibility = SecondarySurfaceVisibility.read(trigger);
    final token = session.open(
      owner: owner,
      cancel: () {
        if (route.isActive) navigator.removeRoute(route);
      },
      isCurrent: () => route.isCurrent && visibility?.value != false,
      canGuardLatchedEvent: () =>
          route.isCurrent || sourceRoute?.isCurrent == true,
      onEscape: onEscape,
    );
    void visibilityChanged() {
      if (visibility?.value == false && session.owns(token)) {
        session.cancelOwner(owner);
      }
    }

    visibility?.addListener(visibilityChanged);
    visibilityChanged();
    unawaited(
      route.popped.then((_) {
        visibility?.removeListener(visibilityChanged);
        session.finish(token);
        if (session.mayRestoreFocus(token) &&
            visibility?.value != false &&
            trigger.mounted &&
            sourceRoute?.isCurrent == true &&
            focus?.context != null &&
            focus?.canRequestFocus == true) {
          focus?.requestFocus();
        }
      }),
    );
  }

  @override
  bool updateShouldNotify(WorkspaceMenuScope oldWidget) =>
      session != oldWidget.session;
}
