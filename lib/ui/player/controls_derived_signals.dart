import 'package:flutter/foundation.dart';

import 'controls_host.dart';

/// 由多个源聚合出的两个布尔信号，各自只驱动一个 ValueListenableBuilder。
///
/// - [cursorHidden]: 全屏 && 控制栏隐藏 && 无面板 → 沉浸式隐藏光标
///   (播放列表/设置面板开启时用户仍在交互，不隐藏鼠标)。
/// - [semanticsExcluded]: resize 期间 || 控制栏隐藏期 → 丢弃控制层语义。
///
/// 由 ControlsListenerHub 的 derived 槽位在任一源变化时调用 [recompute]；
/// ValueNotifier 对相等值不通知，下游只在真实翻转时重建。
class ControlsDerivedSignals {
  ControlsDerivedSignals(this._host);

  final ControlsHost _host;

  /// 光标是否应隐藏。
  final ValueNotifier<bool> cursorHidden = ValueNotifier<bool>(false);

  /// 控制层语义是否应排除。
  final ValueNotifier<bool> semanticsExcluded = ValueNotifier<bool>(false);

  /// 按各源现值重算两个信号。
  ///
  /// 为什么不恒定排除语义：恒定 ExcludeSemantics (v0.0.9 第三刀已回退) 会
  /// 使语义树出现"根节点缺失"型损坏，引擎 AXTree CHECK 在 debug 构建 fatal
  /// abort；故仅 resize 期 + 自动隐藏期条件化排除 (两态用户均读不到控件)。
  void recompute() {
    final visible = _host.autoHide.visible.value;
    // deactivate 窗口内不读 windowMode 之外的任何祖先状态；mode 读取本身
    // 是 ValueNotifier 直读，无 ancestor 查询。
    final fullscreen = _host.isAlive && _host.windowMode.value.isFullscreen;
    cursorHidden.value = fullscreen && !visible && !_host.anyPanelOpen;
    semanticsExcluded.value = (_host.resizing?.value ?? false) || !visible;
  }

  /// 释放两个信号。
  void dispose() {
    cursorHidden.dispose();
    semanticsExcluded.dispose();
  }
}
