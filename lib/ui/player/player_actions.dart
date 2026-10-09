import 'package:flutter/foundation.dart';

import '../../kernel/models/play_mode.dart';

/// 播放器稳定回调集合，沿 `Video.controls` 构建链共享。
class PlayerActions {
  /// 播放/暂停切换。
  final VoidCallback? onPlayPause;

  /// 快退指定毫秒数。
  final void Function(int milliseconds)? onSeekBack;

  /// 快进指定毫秒数。
  final void Function(int milliseconds)? onSeekForward;

  /// 停止并卸载当前媒体。
  final VoidCallback? onStop;

  /// O 键或菜单“打开文件”。
  final VoidCallback? onOpenFile;

  /// F 键或双击视频区域切换全屏。
  final VoidCallback? onToggleFullscreen;

  /// 字幕选择按钮。
  final VoidCallback? onOpenSubtitle;

  /// 设置按钮 — 打开设置窗口（本轮仅 UI 壳，无实际功能）。
  final VoidCallback? onOpenSettings;

  /// 文件拖放完成回调。
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态变化。
  final void Function(bool hovering)? onDragHoverChanged;

  /// ── v0.0.5 播放列表 ──

  /// L 键 / 控制栏按钮 — 开关播放列表面板。
  final VoidCallback? onTogglePlaylist;

  /// 跳到队列上一个条目。
  final VoidCallback? onPreviousEntry;

  /// 跳到队列下一个条目。
  final VoidCallback? onNextEntry;

  /// 循环切换播放模式 (loopAll → loopSingle → shuffle)。
  final VoidCallback? onCyclePlayMode;

  /// 当前播放模式 — 驱动模式按钮图标 (null 时按钮隐藏)。
  final ValueListenable<PlayMode>? playMode;

  const PlayerActions({
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onStop,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onOpenSubtitle,
    this.onOpenSettings,
    this.onFilesDropped,
    this.onDragHoverChanged,
    this.onTogglePlaylist,
    this.onPreviousEntry,
    this.onNextEntry,
    this.onCyclePlayMode,
    this.playMode,
  });

  /// 不可变替换指定回调，其余字段保留原值。
  ///
  /// Returns a copy with the given callbacks replaced; omitted parameters
  /// retain their current value. 供 [PlayerVideoControls] 生成焦点感知的
  /// 设置入口包装 — 原 [PlayerActions] 实例保持不变（宿主 identity 缓存
  /// 依赖不可变契约）。注意：`??` 语义下无法把字段重置为 null（项目惯例，
  /// 参照 PlaylistItem.copyWith）。
  PlayerActions copyWith({
    VoidCallback? onPlayPause,
    void Function(int milliseconds)? onSeekBack,
    void Function(int milliseconds)? onSeekForward,
    VoidCallback? onStop,
    VoidCallback? onOpenFile,
    VoidCallback? onToggleFullscreen,
    VoidCallback? onOpenSubtitle,
    VoidCallback? onOpenSettings,
    void Function(List<String> paths)? onFilesDropped,
    void Function(bool hovering)? onDragHoverChanged,
    VoidCallback? onTogglePlaylist,
    VoidCallback? onPreviousEntry,
    VoidCallback? onNextEntry,
    VoidCallback? onCyclePlayMode,
    ValueListenable<PlayMode>? playMode,
  }) {
    return PlayerActions(
      onPlayPause: onPlayPause ?? this.onPlayPause,
      onSeekBack: onSeekBack ?? this.onSeekBack,
      onSeekForward: onSeekForward ?? this.onSeekForward,
      onStop: onStop ?? this.onStop,
      onOpenFile: onOpenFile ?? this.onOpenFile,
      onToggleFullscreen: onToggleFullscreen ?? this.onToggleFullscreen,
      onOpenSubtitle: onOpenSubtitle ?? this.onOpenSubtitle,
      onOpenSettings: onOpenSettings ?? this.onOpenSettings,
      onFilesDropped: onFilesDropped ?? this.onFilesDropped,
      onDragHoverChanged: onDragHoverChanged ?? this.onDragHoverChanged,
      onTogglePlaylist: onTogglePlaylist ?? this.onTogglePlaylist,
      onPreviousEntry: onPreviousEntry ?? this.onPreviousEntry,
      onNextEntry: onNextEntry ?? this.onNextEntry,
      onCyclePlayMode: onCyclePlayMode ?? this.onCyclePlayMode,
      playMode: playMode ?? this.playMode,
    );
  }
}
