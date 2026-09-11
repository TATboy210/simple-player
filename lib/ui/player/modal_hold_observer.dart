import 'package:flutter/material.dart';

/// 模态路由保持观察者 — 统计打开中的模态弹层 (设置/菜单/对话框) 数量.
///
/// Modal route hold observer — counts open popup routes so the control bar
/// auto-hide can freeze while any modal window is open (v0.0.5).
///
/// 判定: [PopupRoute] 覆盖 showDialog(DialogRoute) / showMenu(PopupMenuRoute)
/// 等全部模态弹层; media_kit 全屏 route 是普通 opaque PageRoute, **不计入**
/// (全屏不是"额外窗口"). 注册于 MaterialApp.navigatorObservers (root
/// navigator — showDialog/showMenu 默认都走 root).
class ModalHoldObserver extends NavigatorObserver {
  /// 打开中的模态弹层数量 — 全局单一数据源.
  static final ValueNotifier<int> openModalCount = ValueNotifier<int>(0);

  static bool _isModal(Route<Object?> route) => route is PopupRoute<Object?>;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (_isModal(route)) openModalCount.value++;
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    if (_isModal(route)) openModalCount.value = _decrement();
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    if (_isModal(route)) openModalCount.value = _decrement();
  }

  /// 下界保护 — 计数永不为负 (路由异常终止时不产生幽灵 hold).
  static int _decrement() =>
      openModalCount.value > 0 ? openModalCount.value - 1 : 0;
}
