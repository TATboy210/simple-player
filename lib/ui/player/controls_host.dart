import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/window_bridge/window_bridge.dart';
import 'auto_hide_controller.dart';
import 'mpv_kit_player_port.dart';
import 'panel_workspace_controller.dart';
import 'player_actions.dart';
import 'workspace_focus_scope.dart';
import 'workspace_menu_session.dart';

/// 控制层宿主视图 — 供命令/点击控制器读取"当前最新"的 widget 数据与生命周期。
///
/// Read-only view of the controls State handed to the small controller
/// classes (keyboard, tap). Getters always reflect the latest widget, so the
/// controllers never capture stale sources across `didUpdateWidget`.
abstract interface class ControlsHost {
  /// 视频端口。
  VideoControlsPort get video;

  /// 引擎 (状态 + 音量写入)。
  MediaEngine get engine;

  /// 宿主动作回调集合。
  PlayerActions get actions;

  /// 窗口模式单一数据源。
  ValueListenable<WindowMode> get windowMode;

  /// 自有菜单会话 (可空)。
  WorkspaceMenuSession? get menuSession;

  /// 共享工作区 (可空)。
  PanelWorkspaceController? get workspace;

  /// 本 route 的焦点注册表 (workspace 为 null 时为 null)。
  WorkspaceFocusRegistry? get workspaceFocus;

  /// legacy 设置可见性 — workspace 接管后恒为 null。
  ValueNotifier<bool>? get legacySettingsVisible;

  /// 播放列表面板可见性 (可空)。
  ValueNotifier<bool>? get playlistVisible;

  /// resize 信号 (可空)。
  ValueListenable<bool>? get resizing;

  /// 控制栏自动隐藏控制器。
  AutoHideController get autoHide;

  /// 本控件是否仍可安全触碰视频端口/祖先 (mounted 且未 deactivate)。
  bool get isAlive;

  /// State 的 BuildContext。
  BuildContext get context;
}

/// 面板可见性派生判定 — 全部由 [ControlsHost] 现值推导，无状态。
extension ControlsHostPanels on ControlsHost {
  /// 任务面板是否开着：工作区以任务表为准，不读其 legacy 布尔镜像。
  bool get hasTaskPanel =>
      workspace?.value.hasTasks ?? (legacySettingsVisible?.value ?? false);

  /// 任一面板(任务/播放列表/自有菜单)开着 — 手势层与光标判定共用。
  bool get anyPanelOpen =>
      hasTaskPanel ||
      (playlistVisible?.value ?? false) ||
      (menuSession?.value ?? false);
}
