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

/// Keep observer identity stable while constraints continue to recalculate geometry.
class _PanelWorkspaceHostState extends State<PanelWorkspaceHost> {
  Listenable? _sources;

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
            child: IgnorePointer(
              ignoring: !visible,
              child: task.builder(context, visible, role),
            ),
          ),
        ),
      ),
    );
  }
}
