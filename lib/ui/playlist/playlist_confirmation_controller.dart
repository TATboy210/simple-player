import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player/workspace_menu_session.dart';
import 'pending_playlist_confirmation.dart';

/// 面板内确认流控制器 — 持有待确认快照、两枚焦点节点, 处理 Tab 陷阱与
/// 早期 ESC.
///
/// Owns the panel-local pending confirmation, its cancel/confirm focus nodes,
/// the U2 Tab trap and the early ESC handler. 面板 State 只在 build 中读取
/// [pending] 并经 [onChanged] 触发重建.
class PlaylistConfirmationController {
  /// [onChanged] 在待确认态翻转且需要重建时调用 (宿主在其中守卫 mounted).
  PlaylistConfirmationController({required this.onChanged});

  /// 状态变化 → 宿主重建回调.
  final VoidCallback onChanged;

  /// 当前待确认快照; null = 无确认卡在显.
  PendingPlaylistConfirmation? pending;

  /// 取消按钮焦点节点.
  final FocusNode cancelFocus = FocusNode(
    debugLabel: 'playlist-confirm-cancel',
  );

  /// 确认按钮焦点节点 — tab-trap 回绕落点 (U2): 卡内只有 cancel/confirm
  /// 两个可聚焦节点, [tabTrap] 据此把 Tab 落点锚定在两节点之间;
  /// debugLabel 供焦点断言与日志定位. [dispose] 成对释放.
  final FocusNode confirmFocus = FocusNode(
    debugLabel: 'playlist-confirm-confirm',
  );

  /// 展示一张确认卡 — 先收掉上一张 (按取消), 再挂新快照并重建.
  void show(PendingPlaylistConfirmation next) {
    finish(false, rebuild: false);
    pending = next;
    onChanged();
  }

  /// Resolve once and remove only this panel's local confirmation.
  void finish(bool confirmed, {bool rebuild = true}) {
    final current = pending;
    pending = null;
    current?.complete(confirmed);
    if (rebuild) onChanged();
  }

  /// Tab/Shift+Tab 焦点陷阱 (U2) — 确认卡是破坏性动作表面, 焦点越卡后
  /// Enter 可能误触卡外播放器控件; 此处抢在 FocusManager 默认 Tab 遍历
  /// (焦点链上溯阶段) 之前返回 handled, 封死越卡路径.
  ///
  /// 两节点回绕下 shift 方向信息退化 — Tab 与 Shift+Tab 都移动到另一
  /// 节点, 故不读 HardwareKeyboard 的 shift 状态.
  KeyEventResult tabTrap(KeyEvent event) {
    // 仅确认卡在显时拦截; KeyRepeat 不移动焦点 (避免长按连跳).
    if (pending == null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (cancelFocus.hasFocus) {
      confirmFocus.requestFocus();
    } else {
      cancelFocus.requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// Early ESC prevents the player's hardware fallback from exiting
  /// fullscreen. 注册为 FocusManager early handler; [visible] 为面板当前
  /// 可见性, [context] 用于路由判定与菜单会话 latch.
  KeyEventResult onEarlyKey(
    KeyEvent event, {
    required bool visible,
    required BuildContext context,
  }) {
    if (pending == null ||
        !visible ||
        ModalRoute.of(context)?.isCurrent != true ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    WorkspaceMenuScope.maybeOf(context)?.session.latchEvent(event);
    if (event is KeyDownEvent) finish(false);
    return KeyEventResult.handled;
  }

  /// 收掉在显确认 (按取消) 并释放焦点节点.
  void dispose() {
    finish(false, rebuild: false);
    cancelFocus.dispose();
    confirmFocus.dispose();
  }
}
