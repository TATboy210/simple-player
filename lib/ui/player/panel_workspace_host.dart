import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../theme/tokens.dart';
import 'panel_workspace_controller.dart';
import 'panel_workspace_layout.dart';

/// 任务在当前快照中的展示角色。
enum WorkspaceTaskRole { hidden, left, center }

/// 受控任务描述 — 生产只注册设置，额外任务由测试注入。
@immutable
class WorkspaceTask {
  const WorkspaceTask({required this.id, required this.builder});
  final String id;
  final Widget Function(BuildContext, bool, WorkspaceTaskRole) builder;
}

/// 稳定父节点工作区宿主 — 角色只改变矩形，不把任务跨父槽位重挂载。
class PanelWorkspaceHost extends StatefulWidget {
  const PanelWorkspaceHost({
    super.key,
    required this.controller,
    required this.tasks,
    this.resizing = false,
    this.resizeSignal,
  });
  final PanelWorkspaceController controller;
  final List<WorkspaceTask> tasks;
  final bool resizing;

  /// Direct resize source; independent of Video or role snapshot rebuilds.
  final ValueListenable<bool>? resizeSignal;

  @override
  State<PanelWorkspaceHost> createState() => _PanelWorkspaceHostState();
}

/// 任务子树缓存项 — 记录构建时的角色/可见性，供复用判定。
class _BuiltTask {
  const _BuiltTask(this.role, this.visible, this.widget);
  final WorkspaceTaskRole role;
  final bool visible;
  final Widget widget;
}

/// Keep observer identity stable while constraints continue to recalculate geometry.
class _PanelWorkspaceHostState extends State<PanelWorkspaceHost> {
  Listenable? _sources;

  /// 每任务最近一次 builder 产物 — 拖窗缩放时 LayoutBuilder 每帧重跑，
  /// 若每帧都调 [WorkspaceTask.builder] 会生成新的面板实例（含新闭包），
  /// 让 Flutter 逐帧重建面板（隐藏态也不例外）。角色/可见性不变就复用
  /// 同一 widget 实例，Element 更新被短路；面板内部依赖的 Inheritance /
  /// Listenable 仍各自驱动重建，尺寸变化走布局而非 build。
  final Map<String, _BuiltTask> _built = {};

  @override
  void initState() {
    super.initState();
    _bindSources();
  }

  /// The builder owns attachment; replacing this object pairs old/new observers.
  void _bindSources() {
    _sources = Listenable.merge([
      widget.controller,
      if (widget.resizeSignal != null) widget.resizeSignal,
    ]);
  }

  @override
  void didUpdateWidget(PanelWorkspaceHost oldWidget) {
    // 任务清单替换（宿主父级重建）意味着 builder 闭包可能捕获了新数据，
    // 缓存的旧产物必须作废。
    if (!identical(oldWidget.tasks, widget.tasks)) _built.clear();
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.resizeSignal, widget.resizeSignal)) {
      _bindSources();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = PanelWorkspaceLayout.calculate(constraints.biggest);
      return ListenableBuilder(
        listenable: _sources ?? widget.controller,
        builder: (context, _) => Stack(
          children: [
            for (final task in widget.tasks)
              _placeTask(context, task, widget.controller.value, layout),
          ],
        ),
      );
    },
  );

  /// 同一 keyed 父链保持 State；隐藏同时排除绘制、输入、焦点与 ticker。
  Widget _placeTask(
    BuildContext context,
    WorkspaceTask task,
    PanelWorkspaceSnapshot snapshot,
    PanelWorkspaceLayout layout,
  ) {
    final role = snapshot.center == task.id
        ? WorkspaceTaskRole.center
        : snapshot.left == task.id
        ? WorkspaceTaskRole.left
        : WorkspaceTaskRole.hidden;
    final visible = role != WorkspaceTaskRole.hidden;
    final rect = role == WorkspaceTaskRole.left ? layout.left : layout.center;
    final cached = _built[task.id];
    final Widget content;
    if (cached != null && cached.role == role && cached.visible == visible) {
      content = cached.widget;
    } else {
      content = task.builder(context, visible, role);
      _built[task.id] = _BuiltTask(role, visible, content);
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // TickerMode adds no RenderObject between Stack and Positioned; the keyed
    // parent chain stays fixed while hidden position and child tickers are muted.
    return TickerMode(
      key: ValueKey(task.id),
      enabled: visible,
      child: AnimatedPositioned.fromRect(
        rect: rect,
        duration: Duration(
          milliseconds:
              (widget.resizeSignal?.value ?? widget.resizing) || reduceMotion
              ? 0
              : Tokens.workspaceMoveDuration,
        ),
        curve: Curves.easeInOut,
        child: ExcludeFocus(
          excluding: !visible,
          child: Offstage(
            offstage: !visible,
            child: IgnorePointer(ignoring: !visible, child: content),
          ),
        ),
      ),
    );
  }
}
