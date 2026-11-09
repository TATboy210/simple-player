import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../kernel/bridge/win32/ime_bridge.dart';
import '../../kernel/window_bridge/window_service.dart';
import 'panel_workspace_controller.dart';
import 'player_actions.dart';
import 'player_screen.dart';
import 'workspace_focus_scope.dart';
import 'workspace_menu_session.dart';

/// 字幕文件可选扩展名 — 与 libmpv 可加载的外挂字幕格式一致.
const List<String> _subtitleExtensions = ['srt', 'ass', 'ssa', 'sub', 'vtt'];

/// 打开系统字幕选择器并返回用户选择的本地路径；取消返回 null。
///
/// 对话框期间临时恢复 IME — 窗口 IMC 已解除（flutter_window.cpp），
/// 原生文件对话框在 NULL IMC 下触发 msctf 崩溃（与打开文件同因）。
/// Side effect: shows a native file dialog.
Future<String?> pickSubtitleFile() async {
  final result = await Win32ImeBridge.withImeRestored(
    // file_picker 13：pickFiles 变为多选，单选语义改用 pickFile。
    () => FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _subtitleExtensions,
    ),
  );
  // 用户取消为 null——视为取消。
  return result?.path;
}

/// 构造 [PlayerScreen] 的稳定回调集合 — State 的 initState 调用一次。
///
/// [current] 每次调用都现读最新 widget：actions 保持同一实例以保护 Video
/// subtree identity，但命令必须发给当前数据源，不能陈旧捕获 controller
/// replacement 前的旧 widget。播放列表入口是否存在在构造时确定
/// （coordinator 为 null = 测试/单文件退路，入口整体隐藏）。
PlayerActions buildPlayerScreenActions({
  required PlayerScreen Function() current,
  required PanelWorkspaceController workspace,
  required WorkspaceMenuSession menus,
  required ValueNotifier<bool> playlistVisible,
  required VoidCallback openSubtitle,
}) {
  final hasPlaylist = current().playlistCoordinator != null;
  return PlayerActions(
    onPlayPause: () => current().controller.togglePlayPause(),
    onSeekBack: (milliseconds) => current().controller.skipBack(milliseconds),
    onSeekForward: (milliseconds) =>
        current().controller.skipForward(milliseconds),
    // 主动停止 → 瞬间卸载媒体并切换空置态（用户决策：无过渡动画）。
    // 不能直接调用 engine.stop：控制器会在确认卸载后清空活动标题。
    onStop: () => unawaited(current().controller.stopCurrentMedia()),
    onOpenFile: () => current().onOpenFile?.call(),
    onOpenSubtitle: openSubtitle,
    // 设置面板 — toggle 语义（成熟播放器惯例）：开→关、关→开；
    // 纯 UI 弹层，不改播放状态，无需空置态隔离。
    // v0.0.6: services bundle 经 PlayerVideoControls 传入挂载的面板。
    onOpenSettings: () => workspace.toggle(WorkspaceTaskIds.settings),
    // 全屏即原生窗口全屏: setMode 驱动 WindowService mode (守卫 + 鼠标隐藏联动),
    // 没有视频 route 可 push/pop.
    onToggleFullscreen: () {
      // 先摘掉自有菜单, 再切换窗口模式.
      menus.cancel();
      final window = current().windowService;
      final entering = window.mode.value != WindowMode.fullscreen;
      window.setMode(entering ? WindowMode.fullscreen : WindowMode.windowed);
    },
    onFilesDropped: (paths) => current().onFilesDropped?.call(paths),
    onDragHoverChanged: (hovering) =>
        current().onDragHoverChanged?.call(hovering),
    // ── v0.0.5 播放列表 — coordinator 为 null 时全部隐藏 (测试退路) ──
    onTogglePlaylist: hasPlaylist
        ? () => playlistVisible.value = !playlistVisible.value
        : null,
    onPreviousEntry: hasPlaylist
        ? () => current().playlistCoordinator?.previous()
        : null,
    onNextEntry: hasPlaylist
        ? () => current().playlistCoordinator?.next()
        : null,
    onCyclePlayMode: hasPlaylist
        ? () => unawaited(current().playlistCoordinator?.cyclePlayMode())
        : null,
    playMode: current().playlistCoordinator?.playMode,
  );
}

/// 字幕延迟调整回调 — `[` `]` 键入口。
///
/// 设置服务在场时路由到持久化通道 (v0.0.6)，否则返回 null（键位不绑定）。
void Function(int deltaMs)? subtitleDelayAdjuster(PlayerScreen screen) {
  final settings = screen.settingsServices?.settings;
  if (settings == null) return null;
  return (deltaMs) {
    settings.setSubtitleDelayMs(settings.subtitleDelayMs + deltaMs);
    // TrackPreference 与持久化双写同步, 避免 open 后重放冲突.
    screen.controller.trackPreferenceService?.recordSubtitleDelay(
      settings.subtitleDelayMs,
    );
  };
}
