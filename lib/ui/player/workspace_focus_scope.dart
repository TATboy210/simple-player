import 'package:flutter/material.dart';

import 'panel_workspace_controller.dart';

/// 关闭来源决定焦点归属，与面板角色变动分离。
enum WorkspaceCloseCause { blank, header }

/// 工作区任务/触发器 id 的唯一引用点 — 消费侧一律引用这里的常量，
/// 禁止散写字符串字面量（typo 类错位改由编译器捕获）。
/// Single source of truth for workspace ids; values keep the historical
/// literals so behaviour is byte-identical after the convergence.
abstract final class WorkspaceTaskIds {
  /// 设置面板共用任务/触发器 id（原 4 文件 11 处散写的 'settings'）。
  static const String settings = 'settings';
}

/// route 本地焦点注册表 — 共享工作区中绝不存 FocusNode。
class WorkspaceFocusRegistry {
  WorkspaceFocusRegistry({required this.controller, required this.player});
  final PanelWorkspaceController controller;
  final FocusNode player;
  final Map<String, FocusScopeNode> tasks = {};
  final Map<String, FocusNode> triggers = {};

  /// 注册任务焦点域（威胁 T-261009-fj6-01 缓解）。
  ///
  /// debug 构建下同 id 已被**不同**实例占用时 assert 响亮失败（消息含 id），
  /// 不再静默顶掉对方；identical 重绑为幂等 no-op，保 SettingsPanel
  /// didChangeDependencies 换注册表的重注册流程不断。
  /// release 构建 assert 编译剥离，赋值照常 → 回落既有 last-wins 语义，
  /// 行为与收敛前逐字节一致、无新增崩溃路径。side effect: 写入 [tasks]。
  void registerTask(String id, FocusScopeNode scope) {
    assert(
      tasks[id] == null || identical(tasks[id], scope),
      'workspace task id "$id" already bound to a different FocusScopeNode',
    );
    tasks[id] = scope;
  }

  /// 注册触发器焦点节点 — 契约同 [registerTask]。side effect: 写入 [triggers]。
  void registerTrigger(String id, FocusNode node) {
    assert(
      triggers[id] == null || identical(triggers[id], node),
      'workspace trigger id "$id" already bound to a different FocusNode',
    );
    triggers[id] = node;
  }

  /// 注销任务焦点域 — 仅现存条目 identical 于传入实例才移除；
  /// 传入不同实例时条目原样保留（防误删后来者的注册，收编消费侧
  /// 既有 identical 守卫语义）。side effect: 可能移除 [tasks] 条目。
  void unregisterTask(String id, FocusScopeNode scope) {
    if (identical(tasks[id], scope)) tasks.remove(id);
  }

  /// 注销触发器焦点节点 — 契约同 [unregisterTask]。
  void unregisterTrigger(String id, FocusNode node) {
    if (identical(triggers[id], node)) triggers.remove(id);
  }

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
