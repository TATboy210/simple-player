import 'package:flutter/foundation.dart';

/// 工作区角色快照 — 不承载业务数据或 route 本地焦点。
/// Immutable roles shared by windowed and fullscreen controls.
@immutable
class PanelWorkspaceSnapshot {
  const PanelWorkspaceSnapshot({this.center, this.left});

  final String? center;
  final String? left;

  /// 是否有可见任务。
  bool get hasTasks => center != null || left != null;

  /// 查询任务是否位于可见角色。
  bool isVisible(String id) => center == id || left == id;
}

/// 小型任务角色控制器 — 各命令发布新快照，不改变任务会话。
class PanelWorkspaceController extends ValueNotifier<PanelWorkspaceSnapshot> {
  PanelWorkspaceController() : super(const PanelWorkspaceSnapshot());

  /// 切换入口自己的可见性。
  void toggle(String id) {
    if (value.isVisible(id)) {
      close(id);
      return;
    }
    // Previous left becomes hidden; its widget/session remains host-owned.
    value = PanelWorkspaceSnapshot(center: id, left: value.center);
  }

  /// 关闭指定可见任务。
  void close(String id) {
    if (value.center == id) {
      value = PanelWorkspaceSnapshot(center: value.left);
    } else if (value.left == id) {
      value = PanelWorkspaceSnapshot(center: value.center);
    }
  }

  /// 显式把左任务与中任务交换。
  void promote(String id) {
    if (value.left != id) return;
    value = PanelWorkspaceSnapshot(center: id, left: value.center);
  }

  /// 空白操作关闭一个中任务，返回是否消费此操作。
  bool closeCenter() {
    final center = value.center;
    if (center == null) return false;
    close(center);
    return true;
  }
}
