import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/services/playlist_coordinator.dart';
import '../dialogs/settings/settings_panel.dart';
import '../playlist/playlist_panel.dart';
import '../theme/tokens.dart';

/// 播放列表面板挂载点 (v0.0.5) — 右侧竖条，圆角与控制栏对齐不贴边，底部
/// 避开控制栏区域；手势层在其下方，点击面板外(视频区)经点击控制器关闭面板。
/// 全屏 route 复制 builder 时自动携带。
class ControlsPlaylistHost extends StatelessWidget {
  const ControlsPlaylistHost({
    super.key,
    required this.coordinator,
    required this.visible,
    required this.scrubbing,
    required this.resizing,
    required this.settingsServices,
  });

  /// 面板数据源与动作入口。
  final PlaylistCoordinator coordinator;

  /// 宿主共享的可见性 notifier。
  final ValueNotifier<bool> visible;

  /// seek 拖动挂起玻璃模糊 (v0.0.8.2)。
  final ValueListenable<bool> scrubbing;
  final ValueListenable<bool>? resizing;

  /// 设置服务集合 — 提供断点续播总开关 (v0.0.6)。
  final SettingsServicesBundle? settingsServices;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (_, isVisible, _) => Positioned(
        right: Tokens.controlBarMarginH,
        top: Tokens.spMd,
        bottom:
            Tokens.controlBarMarginBottom +
            Tokens.controlBarHeight +
            Tokens.spMd,
        child: _panel(isVisible),
      ),
    );
  }

  PlaylistPanel _panel(bool isVisible) {
    final c = coordinator;
    return PlaylistPanel(
      entries: c.entries,
      currentIndex: c.currentIndex,
      // v0.0.6.2: 上次播放锚点 — 停止态高亮"上次会话那条"。
      lastPlayedPath: c.lastPlayedPath,
      visible: isVisible,
      scrubbing: scrubbing,
      resizing: resizing,
      onClose: () => visible.value = false,
      onPlayEntry: (index) => unawaited(c.playEntryAt(index)),
      onResumeEntry: (index) => unawaited(c.resumeEntryAt(index)),
      onRemoveEntry: (index) => unawaited(c.removeEntryAt(index)),
      // v0.0.7: 批量删除 — 确认对话框后移除选中条目，Coordinator 内按
      // P-Thumb §40.2 契约同步 evict 缩略图。
      onRemoveEntries: (indices) => unawaited(c.removeEntriesAt(indices)),
      playMode: c.playMode,
      onCyclePlayMode: () => unawaited(c.cyclePlayMode()),
      sortKey: c.sortKey,
      sortAscending: c.sortAscending,
      onSortSelected: (key) => unawaited(c.sortEntries(key)),
      // v0.0.6: 断点续播总开关 — 设置关闭时条目断点 UI 隐藏。
      resumeEnabled: settingsServices?.settings?.resumeEnabled,
    );
  }
}
