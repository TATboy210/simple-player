import 'package:flutter/material.dart';

import 'panel_workspace_controller.dart';

/// 关闭来源决定焦点归属，与面板角色变动分离。
enum WorkspaceCloseCause { blank, header }

/// route 本地焦点注册表 — 共享工作区中绝不存 FocusNode。
class WorkspaceFocusRegistry {
  WorkspaceFocusRegistry({required this.controller, required this.player});
  final PanelWorkspaceController controller;
  final FocusNode player;
  final Map<String, FocusScopeNode> tasks = {};
  final Map<String, FocusNode> triggers = {};

  /// 关闭后在新角色生效帧恢复有效焦点；未附着节点只能回播放器。
  void close(String id, WorkspaceCloseCause cause) {
    controller.close(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final promoted = controller.value.center;
      final task = tasks[promoted];
      final trigger = triggers[id];
      final target = cause == WorkspaceCloseCause.blank
          ? player
          : task?.focusedChild ?? task ?? trigger ?? player;
      if (target.context != null && target.canRequestFocus) {
        target.requestFocus();
      } else if (player.context != null && player.canRequestFocus) {
        player.requestFocus();
      }
    });
    // Role-only callers may have no widget listener; guarantee restoration runs.
    WidgetsBinding.instance.scheduleFrame();
  }
}

/// route 本地入口与任务焦点接线，不影响 Video subtree identity。
class WorkspaceFocusScope extends InheritedWidget {
  const WorkspaceFocusScope({
    super.key,
    required this.registry,
    required super.child,
  });
  final WorkspaceFocusRegistry registry;

  /// 独立组件可无工作区 scope，维持原调用方式。
  static WorkspaceFocusRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceFocusScope>()
      ?.registry;
  @override
  bool updateShouldNotify(WorkspaceFocusScope oldWidget) =>
      registry != oldWidget.registry;
}
