import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'workspace_focus_scope.dart';
import 'workspace_menu_session.dart';

/// 控制层外围作用域 — 菜单会话 > 焦点注册表 的可选嵌套 + 语义条件排除。
///
/// 拆出 State.build 以保持其行数；嵌套顺序与既有契约一致：
/// 语义门 (最外) → 菜单作用域 → 焦点作用域 → child。
class ControlsScopes extends StatelessWidget {
  const ControlsScopes({
    super.key,
    required this.menuSession,
    required this.focusRegistry,
    required this.onEscape,
    required this.semanticsExcluded,
    required this.child,
  });

  final WorkspaceMenuSession? menuSession;
  final WorkspaceFocusRegistry? focusRegistry;

  /// 菜单作用域的 ESC 命令 (route-local 退出全屏)。
  final bool Function() onEscape;

  /// resize/隐藏期排除语义的信号；null = 测试旁路，保留裸树供语义断言。
  final ValueListenable<bool>? semanticsExcluded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registry = focusRegistry;
    final menus = menuSession;
    final focusScoped = registry == null
        ? child
        : WorkspaceFocusScope(registry: registry, child: child);
    final scoped = menus == null
        ? focusScoped
        : WorkspaceMenuScope(
            session: menus,
            onEscape: onEscape,
            child: focusScoped,
          );
    final excluded = semanticsExcluded;
    if (excluded == null) return scoped;
    // 用 ValueListenableBuilder 而非 .value 直读：父 build 不被信号触发
    // (build-boundary 契约)，须 VLB 自身监听 settle 翻回。resize 期间控制栏
    // 子树随 MediaQuery 每帧重发语义会让 AXTree 每帧同步失败 + 日志洪流。
    return ValueListenableBuilder<bool>(
      valueListenable: excluded,
      child: scoped,
      builder: (_, isExcluded, inner) =>
          ExcludeSemantics(excluding: isExcluded, child: inner ?? scoped),
    );
  }
}
