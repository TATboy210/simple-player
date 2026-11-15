import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../shared/osd_overlay.dart';
import '../theme/tokens.dart';
import 'auto_hide_controller.dart';
import 'control_bar.dart';
import 'control_bar_view_model.dart';
import 'controls_bar_visibility.dart';
import 'panel_workspace_controller.dart';
import 'player_actions.dart';
import 'player_controls_state.dart';
import 'workspace_focus_scope.dart';

/// 控制栏层 — OSD + 构建一次的 [ControlBar] 子树 (RepaintBoundary 隔离)。
///
/// v0.0.6.1 (官方 perf best-practice: "build that part of the subtree once
/// and pass it as a child")：ControlBar 按钮子树**构建一次**并跨显隐翻转复用
/// — FadeTransition 是渲染层驱动动画，翻转本无需重建按钮树。失效点：
/// actions 替换 / 标题源替换 / resizing 源替换 (见 [didUpdateWidget])。
/// 数据绑定 [ControlBarViewModel] 同寿命缓存，只在 actions 变化时重建。
class ControlsBarLayer extends StatefulWidget {
  const ControlsBarLayer({
    super.key,
    required this.controlsState,
    required this.actions,
    required this.isFullscreen,
    required this.isIdle,
    required this.titleListenable,
    required this.autoHide,
    required this.decoration,
    required this.scrubbing,
    required this.resizing,
    required this.workspace,
    required this.workspaceFocus,
    required this.onToggleFullscreen,
  });

  /// 展示状态 (订阅 player.stream) — 其 notifier identity 跨 source 切换保留。
  final PlayerControlsState controlsState;
  final PlayerActions actions;
  final ValueListenable<bool> isFullscreen;
  final ValueListenable<bool> isIdle;
  final ValueListenable<String> titleListenable;
  final AutoHideController autoHide;

  /// playing/idle 装饰动画 (共享 AnimationController)。
  final Animation<double> decoration;

  /// seek 拖动挂起信号 — 玻璃模糊短暂停用 (v0.0.8.2)。
  final ValueNotifier<bool> scrubbing;
  final ValueListenable<bool>? resizing;
  final PanelWorkspaceController? workspace;
  final WorkspaceFocusRegistry? workspaceFocus;
  final VoidCallback onToggleFullscreen;

  @override
  State<ControlsBarLayer> createState() => _ControlsBarLayerState();
}

class _ControlsBarLayerState extends State<ControlsBarLayer> {
  ControlBarViewModel? _vm;
  Widget? _barCache;

  /// 焦点感知 actions 包装缓存 — 源 [PlayerActions] identity → 包装产物，
  /// identity 相同则复用，包装对象 identity 跨 build 稳定。
  PlayerActions? _actionsSource;
  PlayerActions? _actionsWrapped;

  @override
  void didUpdateWidget(covariant ControlsBarLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // actions 变化仅刷新含回调闭包的 vm；播放状态 notifier 仍复用，避免把
    // 一次宿主回调替换扩散成整套订阅重建。
    if (oldWidget.actions != widget.actions) _vm = null;
    // 缓存子树持有 vm/标题/resizing 引用，任一源替换即失效。
    if (_vm == null ||
        oldWidget.titleListenable != widget.titleListenable ||
        oldWidget.resizing != widget.resizing) {
      _barCache = null;
    }
  }

  /// 创建控制栏只读数据绑定；仅 actions 改变时重建。
  ControlBarViewModel _createViewModel() {
    final state = widget.controlsState;
    final actions = widget.actions;
    return ControlBarViewModel(
      isPlaying: state.isPlaying,
      position: state.positionMs,
      duration: state.durationMs,
      volume: state.volume01,
      isMuted: state.isMuted,
      rate: state.rate,
      isFullscreen: widget.isFullscreen,
      onSeek: state.seek,
      // 以下空回调为空置态兜底 (未播放时控制栏可显但无动作)。
      // ignore: no-empty-block
      onPlayPause: actions.onPlayPause ?? () {},
      // ignore: no-empty-block
      onSeekBack: actions.onSeekBack ?? (_) {},
      // ignore: no-empty-block
      onSeekForward: actions.onSeekForward ?? (_) {},
      onToggleMute: state.toggleMute,
      onSetVolume: state.setVolume,
      // 音量源身份键 — controlsState 在 State 生命周期内身份恒定。
      volumeSourceKey: state,
      onSetRate: state.setRate,
      // v0.0.5 队列步进 — null 时 CenterGroup 隐藏切曲按钮。
      onPreviousEntry: actions.onPreviousEntry,
      onNextEntry: actions.onNextEntry,
    );
  }

  /// 焦点感知的控制栏 actions — 仅把 onOpenSettings 换成 [_handleSettingsEntry]。
  ///
  /// 原回调为 null 时不建包装 (设置按钮本就不渲染，透传零行为差)；
  /// workspace 为 null 的 legacy 独立控件场景同样恒透传原对象。
  PlayerActions _focusAwareActions() {
    final source = widget.actions;
    if (source.onOpenSettings == null || widget.workspace == null) {
      return source;
    }
    if (identical(_actionsSource, source)) return _actionsWrapped ?? source;
    _actionsSource = source;
    return _actionsWrapped = source.copyWith(
      onOpenSettings: _handleSettingsEntry,
    );
  }

  /// 设置按钮入口 — 打开方向透传原回调，关闭方向接入 registry 焦点归还链。
  ///
  /// 为什么：此前关闭方向经 `workspace.toggle` 快照直改，绕过
  /// [WorkspaceFocusRegistry] 的 post-frame 焦点归还，面板卸载后焦点跌落
  /// 路由死键区；标题 X 走 `close(header)` 有完整归还链，本 handler 对齐同一
  /// 调用形。按压时才读 registry 现值 (State 成员不捕获旧实例)。
  void _handleSettingsEntry() {
    final original = widget.actions.onOpenSettings;
    if (original == null) return;
    final workspace = widget.workspace;
    if (workspace != null &&
        workspace.value.isVisible(WorkspaceTaskIds.settings)) {
      widget.workspaceFocus?.close(
        WorkspaceTaskIds.settings,
        WorkspaceCloseCause.header,
      );
      return;
    }
    original();
  }

  /// seek 拖动包装 — 置位挂起信号并透传 auto-hide 原语义 (拖动中冻结隐藏
  /// 计时)。瞬时 tap 的 start/end 同帧配对翻转由 Flutter 合帧消化。
  void _handleSeekStart() {
    widget.scrubbing.value = true;
    widget.autoHide.onSeekStart();
  }

  void _handleSeekEnd() {
    widget.scrubbing.value = false;
    widget.autoHide.onSeekEnd();
  }

  Widget _createBar() {
    final hide = widget.autoHide;
    return ControlBar(
      vm: _vm ??= _createViewModel(),
      actions: _focusAwareActions(),
      isIdleListenable: widget.isIdle,
      titleListenable: widget.titleListenable,
      // 透明尾段停用 backdrop readback，但保留完整交互祖先链。
      opacity: hide.opacity,
      enableBlur: true,
      decoration: widget.decoration,
      resizing: widget.resizing,
      scrubbing: widget.scrubbing,
      onToggleFullscreen: widget.onToggleFullscreen,
      onSeekStart: _handleSeekStart,
      onSeekEnd: _handleSeekEnd,
      onInteractionStart: hide.onInteractionStart,
      onInteractionEnd: hide.onInteractionEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bar = _barCache ??= _createBar();
    return RepaintBoundary(
      child: Stack(
        children: [
          // OSD 不依赖 engine.state/currentFileName，保持稳定 Element；
          // 上下限定在视口内、控制栏之上，长摘要不越界。
          Positioned(
            top: Tokens.spMd,
            bottom:
                Tokens.controlBarMarginBottom +
                Tokens.controlBarHeight +
                Tokens.spMd,
            left: Tokens.controlBarMarginH,
            right: Tokens.controlBarMarginH,
            child: OsdOverlay(resizing: widget.resizing),
          ),
          ControlsBarVisibility(autoHide: widget.autoHide, child: bar),
          // 错误展示统一走 ErrorCardHost (app.dart builder 全局挂载, D-07)。
        ],
      ),
    );
  }
}
