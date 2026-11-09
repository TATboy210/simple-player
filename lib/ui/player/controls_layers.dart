import 'package:flutter/material.dart';

import 'auto_hide_controller.dart';
import 'controls_bar_layer.dart';
import 'controls_cursor_region.dart';
import 'controls_empty_gesture.dart';
import 'controls_panels_layer.dart';
import 'controls_tap_controller.dart';
import 'player_controls_state.dart';
import 'player_video_controls.dart';
import 'workspace_focus_scope.dart';

/// 控制层 Stack — 自底向上: 空状态/手势 → 播放列表 → 设置 → OSD+控制栏 →
/// 鼠标区域。
///
/// 由编排 State 提供稳定的内部对象，其余数据直接取自 [config] (宿主 widget)。
/// 各层各自监听所需信号，本 widget 自身不订阅任何 notifier。
class ControlsLayers extends StatelessWidget {
  const ControlsLayers({
    super.key,
    required this.config,
    required this.controlsState,
    required this.autoHide,
    required this.decoration,
    required this.isFullscreen,
    required this.isIdle,
    required this.scrubbing,
    required this.cursorHidden,
    required this.tap,
    required this.workspaceFocus,
    required this.panelSources,
    required this.anyPanelOpen,
    required this.onToggleFullscreen,
  });

  final PlayerVideoControls config;
  final PlayerControlsState controlsState;
  final AutoHideController autoHide;
  final Animation<double> decoration;
  final ValueNotifier<bool> isFullscreen;
  final ValueNotifier<bool> isIdle;
  final ValueNotifier<bool> scrubbing;
  final ValueNotifier<bool> cursorHidden;
  final ControlsTapController tap;
  final WorkspaceFocusRegistry? workspaceFocus;

  /// 面板可见性源 (工作区/legacy 设置/菜单会话/播放列表)。
  final List<Listenable?> panelSources;
  final bool Function() anyPanelOpen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final c = config;
    return Stack(
      children: [
        Positioned.fill(
          child: ControlsEmptyGestureLayer(
            engine: c.engine,
            currentFileName: c.currentFileName,
            emptyState: c.emptyState,
            panelSources: panelSources,
            anyPanelOpen: anyPanelOpen,
            onTap: tap.handleTap,
            onEmptyAreaTap: tap.handleEmptyAreaTap,
          ),
        ),
        ControlsPanelsLayer(
          playlistCoordinator: c.playlistCoordinator,
          playlistVisible: c.playlistVisible,
          workspace: c.workspace,
          legacySettingsVisible: c.settingsVisible,
          focusRegistry: workspaceFocus,
          settingsSession: c.settingsSession,
          settingsServices: c.settingsServices,
          scrubbing: scrubbing,
          resizing: c.resizing,
        ),
        ControlsBarLayer(
          controlsState: controlsState,
          actions: c.actions,
          isFullscreen: isFullscreen,
          isIdle: isIdle,
          titleListenable: c.currentFileName,
          autoHide: autoHide,
          decoration: decoration,
          scrubbing: scrubbing,
          resizing: c.resizing,
          workspace: c.workspace,
          workspaceFocus: workspaceFocus,
          onToggleFullscreen: onToggleFullscreen,
        ),
        // 顶层 MouseRegion 监听 auto-hide 可见性 + 面板可见性，保持鼠标交互
        // 与 cursor 语义 (面板开启时用户仍在交互，全屏静置不隐藏鼠标)。
        Positioned.fill(
          child: ControlsCursorRegion(
            autoHide: autoHide,
            cursorHidden: cursorHidden,
          ),
        ),
      ],
    );
  }
}
