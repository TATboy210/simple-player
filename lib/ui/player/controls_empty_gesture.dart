import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import 'controls_listener_hub.dart';

/// 空状态页 + 视频区手势层。
///
/// 只监听空状态判定所需的 engine.state / 文件名，以及面板可见性源；
/// 文件名或 idle 变化时不会触发 OSD、控制栏和鼠标区域的重建。
class ControlsEmptyGestureLayer extends StatefulWidget {
  const ControlsEmptyGestureLayer({
    super.key,
    required this.engine,
    required this.currentFileName,
    required this.emptyState,
    required this.panelSources,
    required this.anyPanelOpen,
    required this.onTap,
    required this.onEmptyAreaTap,
  });

  final MediaEngine engine;
  final ValueListenable<String> currentFileName;

  /// 空状态页 — null 时不渲染且恒不视为空置态 (测试装配)。
  final Widget? emptyState;

  /// 面板可见性源 (工作区/legacy 设置/菜单会话/播放列表)。
  final List<Listenable?> panelSources;

  /// 读取"任一面板开着"的现值。
  final bool Function() anyPanelOpen;

  /// 普通点击 (非空置态)。
  final VoidCallback onTap;

  /// 空置态面板外点击 (关面板)。
  final VoidCallback onEmptyAreaTap;

  @override
  State<ControlsEmptyGestureLayer> createState() =>
      _ControlsEmptyGestureLayerState();
}

class _ControlsEmptyGestureLayerState extends State<ControlsEmptyGestureLayer> {
  /// 空状态判定监听器 — 仅在源变化时重建，避免 build 中反复创建新实例。
  Listenable _identity = const _NeverNotify();
  Listenable? _panels;
  List<Listenable?> _panelSources = const [];

  @override
  void initState() {
    super.initState();
    _refreshListenables(identityChanged: true);
  }

  @override
  void didUpdateWidget(covariant ControlsEmptyGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final w = widget;
    // 身份源未变时沿用旧合并监听，避免 ListenableBuilder 每次父 build 重挂。
    final identityChanged =
        oldWidget.engine.state != w.engine.state ||
        oldWidget.currentFileName != w.currentFileName;
    _refreshListenables(identityChanged: identityChanged);
  }

  /// 源 identity 变化时才重建合并监听 (build 内重建会让 ListenableBuilder
  /// 反复重挂监听)。
  void _refreshListenables({required bool identityChanged}) {
    final w = widget;
    if (identityChanged) {
      _identity = Listenable.merge([w.engine.state, w.currentFileName]);
    }
    if (!sameSources(_panelSources, w.panelSources)) {
      _panelSources = List<Listenable?>.of(w.panelSources);
      _panels = mergeNonNull(_panelSources);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _identity,
      builder: (context, _) {
        final emptyActive = _isEmptyActive();
        return Stack(
          children: [
            if (widget.emptyState case final page?)
              Positioned.fill(
                child: emptyActive ? page : const SizedBox.shrink(),
              ),
            Positioned.fill(
              bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
              child: _GestureArea(
                emptyActive: emptyActive,
                panels: _panels,
                anyPanelOpen: widget.anyPanelOpen,
                onTap: widget.onTap,
                onEmptyAreaTap: widget.onEmptyAreaTap,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 空置页渲染条件：有空状态页 && idle && 无媒体。
  bool _isEmptyActive() =>
      widget.emptyState != null &&
      widget.engine.state.value == MediaState.idle &&
      !widget.engine.hasMedia;
}

/// 永不通知的占位 Listenable — 仅用于 initState 前的字段初值。
class _NeverNotify implements Listenable {
  const _NeverNotify();

  @override
  // ignore: no-empty-block
  void addListener(VoidCallback listener) {}

  @override
  // ignore: no-empty-block
  void removeListener(VoidCallback listener) {}
}

/// 手势命中层 — onTap 三态依赖面板可见性，故 GestureDetector 必须在面板
/// 监听 builder 内构建。
class _GestureArea extends StatelessWidget {
  const _GestureArea({
    required this.emptyActive,
    required this.panels,
    required this.anyPanelOpen,
    required this.onTap,
    required this.onEmptyAreaTap,
  });

  final bool emptyActive;
  final Listenable? panels;
  final bool Function() anyPanelOpen;
  final VoidCallback onTap;
  final VoidCallback onEmptyAreaTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: panels ?? const _NeverNotify(),
      builder: (context, _) {
        // 空置态无面板时 onTap 必须为 null — translucent 手势层恒把自己加入
        // 命中结果，只要注册了 TapGestureRecognizer 就先注册先赢 (eager
        // winner)，底层空置页"打开文件"按钮的 InkWell 被拒 (fb9d383f 回归
        // 根因；外层 IgnorePointer 只挡 child 挡不住 GD 自身)。null = 不注册
        // recognizer = 让位按钮。
        final VoidCallback? handler = !emptyActive
            ? onTap
            : (anyPanelOpen() ? onEmptyAreaTap : null);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: handler,
          // translucent 下 GD 无论子节点命中与否都参战 — child 仅撑命中体
          // (无 child 零尺寸收不到指针事件)。
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
