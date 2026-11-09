import 'package:flutter/material.dart';
// services: KeyDownEvent / LogicalKeyboardKey / KeyEventResult / FocusNode
// (material.dart 不完整导出 services 的键盘事件类型)
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'controls_host.dart';
import 'player_keyboard_actions.dart';

/// 控制层命令 — 全屏切换/退出与 controls 内 Focus 键盘最小集。
///
/// 所有入口都经 [ControlsHost.isAlive] 与端口 isMounted 双重守卫：宿主回调
/// 可能同步使本控件或视频面失效，触碰视频端口前必须重新校验。
class ControlsCommands {
  ControlsCommands(this._host);

  final ControlsHost _host;

  bool get _portUsable => _host.isAlive && _host.video.isMounted;

  /// 切换全屏 — 双击与全屏按钮共用入口。
  ///
  /// 全屏由宿主经 WindowService.setMode 切换原生窗口 (actions.onToggleFullscreen)；
  /// 视频面侧钩子 `toggleFullscreen` 生产实现为 no-op，仅作测试可观测落点。
  /// side effect: 先取消自有菜单，再回调宿主。
  void toggleFullscreen() {
    if (!_portUsable) return;
    _host.menuSession?.cancel();
    _host.actions.onToggleFullscreen?.call();
    // 宿主回调可能同步使本控件失效，触碰视频面前重新校验生命周期。
    if (!_portUsable) return;
    _host.video.toggleFullscreen();
  }

  /// Route-local ESC：取消菜单 → 通知宿主 → 守卫后退出视频面全屏。
  /// 窗口模式仍是全屏状态的唯一权威；非全屏时返回 false 让按键冒泡。
  bool exitFullscreen() {
    if (!_host.windowMode.value.isFullscreen) return false;
    _host.menuSession?.cancel();
    if (!_portUsable) return false;
    _host.actions.onToggleFullscreen?.call();
    if (_portUsable) _host.video.exitFullscreen();
    return true;
  }

  /// 键盘事件处理 — controls 内 Focus 最小集。
  ///
  /// ESC(退出全屏)/F(切换全屏)/Space(播放暂停)/←→(seek)/↑↓(音量，经
  /// [adjustVolumeByKeyboard] 与窗口态共享唯一实现 — v0.0.12 U3)。其余键
  /// 返回 ignored 冒泡给窗口态 KeyboardHandler。
  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    // 自有菜单守卫：拒绝播放器回调，但让精确菜单路由导航/激活。
    // latch 跨同步关闭、替换与全屏宿主拆除保持有效。
    final menus = _host.menuSession;
    if (menus?.guardsPlayerEvent(event) == true) return KeyEventResult.ignored;
    // 同步 deactivate 之后绝不查询祖先。
    if (!_portUsable) return KeyEventResult.ignored;
    // 自有菜单之上的对话框须让出原生按键；空注入会话保留菜单前的
    // route-local 分发契约。
    if (menus?.currentToken != null &&
        ModalRoute.of(_host.context)?.isCurrent == false) {
      return KeyEventResult.ignored;
    }
    // 长按连续 seek 是桌面播放器惯例：仅 ←/→ 的 KeyRepeat 放行；其余键按住
    // 重复一律忽略防连发误触 (对齐 KeyboardHandler 门禁, T-261009-fiw-01)。
    // Held-key repeat: only ←/→ repeats drive seeking.
    final key = event.logicalKey;
    final isSeekRepeat =
        event is KeyRepeatEvent &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight);
    if (event is! KeyDownEvent && !isSeekRepeat) return KeyEventResult.ignored;
    return _dispatch(key);
  }

  KeyEventResult _dispatch(LogicalKeyboardKey key) {
    final actions = _host.actions;
    if (key == LogicalKeyboardKey.escape) {
      return exitFullscreen() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyF) {
      toggleFullscreen();
    } else if (key == LogicalKeyboardKey.space) {
      actions.onPlayPause?.call();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      actions.onSeekBack?.call(Tokens.skipShortMs);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      actions.onSeekForward?.call(Tokens.skipLongMs);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      // 全屏 route 无 KeyboardHandler，此前 ↑↓ 落 ignored 成死键；controls 内
      // 直接消费并与窗口态共享同一 adjuster 防双路径漂移。
      adjustVolumeByKeyboard(_host.engine, keyboardVolumeStep);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      adjustVolumeByKeyboard(_host.engine, -keyboardVolumeStep);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}
