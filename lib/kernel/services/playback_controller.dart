/// Services 层播放控制模块 — 门面模式统一入口
///
/// 本文件实现 [PlaybackController] 作为播放器运行时能力的统一门面，
/// 组合 [PlaybackNavigator] / [FileOperations] / [PlaybackStateManager] / [AutoAdvancePolicy] 四个子模块，
/// UI 层只与本类交互，不直接访问子模块。
///
/// 架构位置：PlayerViewModel → **PlaybackController** → PlaybackNavigator / FileOperations / PlaybackStateManager / AutoAdvancePolicy → MediaEngine
/// 设计模式：Facade（门面模式）— 简化 UI 层对多个子模块的调用路径
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/engine_state.dart';
import '../models/play_mode.dart';
import '../persistence/playlist_store.dart';
import '../persistence/settings_store.dart';
import '../playlist/playlist.dart';
import '../utils/debug_probe.dart';
import '../diagnostics/kernel_logger.dart';
import 'auto_advance_policy.dart';
import 'file_operations.dart';
import 'playback_navigator.dart';
import 'playback_state_manager.dart';
import 'subtitle_service.dart';
import 'track_preference_service.dart';

final log = KernelLogger.I;

/// 播放控制器 — 播放器全部运行时能力的统一门面入口
///
/// 组合 [PlaybackNavigator] / [FileOperations] / [PlaybackStateManager] / [AutoAdvancePolicy] 四个子模块，
/// UI 层只与本类交互。所有子模块通过 [PlaybackContract] 接口访问共享依赖。
///
/// 职责划分：
/// - 播放导航：委托 [PlaybackNavigator]（playIndex / playNext / playPrevious）
/// - 文件操作：委托 [FileOperations]（openAndPlay / addFiles）
/// - 状态管理：委托 [PlaybackStateManager]（设置恢复 / 断点保存 / 销毁持久化）
/// - 自动连播：委托 [AutoAdvancePolicy]（completed → loopSingle / next）
/// - 播放列表 CRUD：直接管理 removeAt / reorder / clearPlaylist / togglePlayMode
///
/// 生命周期：init() → 使用 → dispose()
/// init() 内部调用 stateManager.init() + autoAdvance.init()。
class PlaybackController {
  PlaybackController({
    required this.engine,
    required this.playlist,
    required VoidCallback onNeedRebuild,
    void Function(PlayerError error)? onError,
    SubtitleService? subtitleService,
    TrackPreferenceService? trackPreferenceService,
  }) : _onNeedRebuild = onNeedRebuild,
       _onError = onError,
       _subtitleService = subtitleService,
       _trackPreferenceService = trackPreferenceService {
    navigator = PlaybackNavigator(this);
    fileOps = FileOperations(this);
    stateManager = PlaybackStateManager(this);
    autoAdvance = AutoAdvancePolicy(this);
  }

  /// 视频渲染引擎实例.
  ///
  /// Media engine instance.
  final MediaEngine engine;

  /// 播放列表管理器 — 包含当前播放索引、播放模式、历史记录.
  ///
  /// Playlist manager — holds current index, play mode, and history.
  final Playlist playlist;

  /// UI 重建回调 — 子模块播放列表变更时调用
  final VoidCallback _onNeedRebuild;

  /// 错误回调 — 子模块捕获异常时调用（null 表示忽略错误）
  final void Function(PlayerError error)? _onError;

  /// 字幕服务 — 可选依赖，null 表示无外挂字幕支持
  final SubtitleService? _subtitleService;

  /// 轨道偏好服务 — 可选依赖，null 表示不持久化轨道偏好
  final TrackPreferenceService? _trackPreferenceService;

  /// 播放导航子模块 — 索引跳转和并发 open() 守卫.
  ///
  /// Playback navigation sub-module — index jumping and concurrent open() guard.
  late final PlaybackNavigator navigator;

  /// 文件操作子模块 — 文件打开和批量添加.
  ///
  /// File operations sub-module — open and batch-add files.
  late final FileOperations fileOps;

  /// 状态管理子模块 — 设置恢复、断点保存、销毁持久化.
  ///
  /// State management sub-module — settings restore, breakpoint save, dispose persistence.
  late final PlaybackStateManager stateManager;

  /// 自动连播策略 — completed → loopSingle / next.
  ///
  /// Auto-advance policy — completed → loopSingle / next.
  late final AutoAdvancePolicy autoAdvance;

  /// 调试探针 — 记录播放控制操作的耗时和事件（编译时开关 kDebugMode）.
  ///
  /// Debug probe — records timing and events (compile-time kDebugMode gate).
  final DebugProbe probe = DebugProbeRegistry.register('playback');

  /// 当前播放文件名（仅文件名，不含路径）— UI 层显示标题栏文件名.
  ///
  /// Current playback file name (basename only) — displayed in title bar.
  final ValueNotifier<String> currentFileName = ValueNotifier('');

  /// 通知 UI 层播放列表已变更.
  ///
  /// Notifies UI layer that the playlist has changed.
  void onNeedRebuild() => _onNeedRebuild();

  /// 错误回调（子模块通过 `_controller.onError?.call(error)` 调用）.
  ///
  /// Error callback invoked by sub-modules.
  void Function(PlayerError error)? get onError => _onError;

  /// 获取字幕服务（可能为 null）.
  ///
  /// Returns the subtitle service, or null if not configured.
  SubtitleService? get subtitleService => _subtitleService;

  /// 获取轨道偏好服务（可能为 null）.
  ///
  /// Returns the track preference service, or null if not configured.
  TrackPreferenceService? get trackPreferenceService => _trackPreferenceService;

  /// 保存播放列表 — 异步写入，跨模块共享.
  ///
  /// Persists playlist to storage. Shared across sub-modules.
  void savePlaylist() {
    PlaylistStore.save(playlist);
  }

  // ── 转发 — UI 层的统一入口 ──
  // 所有播放/文件操作委托给对应子模块，UI 层无需关心具体实现。

  /// 播放指定索引 — 委托 [PlaybackNavigator.playIndex].
  ///
  /// Plays the track at [i]. Delegates to [PlaybackNavigator.playIndex].
  Future<void> playIndex(int i) => navigator.playIndex(i);

  /// 播放下一首 — 委托 [PlaybackNavigator.playNext].
  ///
  /// Plays the next track. Delegates to [PlaybackNavigator.playNext].
  Future<void> playNext() => navigator.playNext();

  /// 播放上一首 — 委托 [PlaybackNavigator.playPrevious].
  ///
  /// Plays the previous track. Delegates to [PlaybackNavigator.playPrevious].
  Future<void> playPrevious() => navigator.playPrevious();

  /// 打开并播放文件 — 委托 [FileOperations.openAndPlay].
  ///
  /// Opens and plays a file. Delegates to [FileOperations.openAndPlay].
  Future<bool> openAndPlay(String p) => fileOps.openAndPlay(p);

  /// 批量添加文件 — 委托 [FileOperations.addFiles].
  ///
  /// Batch-adds files. Delegates to [FileOperations.addFiles].
  Future<int> addFiles(List<String> p) => fileOps.addFiles(p);

  /// 最近一次路径校验错误（null 表示无错误）— 委托 [FileOperations.validationError].
  ///
  /// Most recent path validation error (null = none). Delegates to [FileOperations.validationError].
  ValueNotifier<String?> get validationError => fileOps.validationError;

  // ── 播放列表 CRUD ──

  /// 移除播放列表中指定索引.
  ///
  /// Removes the playlist entry at [index]. If it is the currently playing
  /// track, stops the engine and attempts to play the next item.
  /// Notifies UI rebuild and persists playlist after removal.
  Future<void> removeAt(int index) async {
    final wasCurrent = playlist.currentIndex == index;
    playlist.removeAt(index);
    if (wasCurrent) {
      engine.stop();
      final next = playlist.peekNext();
      if (next >= 0) {
        await navigator.playIndex(next);
      }
    }
    _onNeedRebuild();
    savePlaylist();
  }

  /// 拖拽排序 — 交换播放列表中两个位置的项.
  ///
  /// Drag-reorder — swaps two playlist entries.
  void reorder(int oldIndex, int newIndex) {
    playlist.reorder(oldIndex, newIndex);
    _onNeedRebuild();
    savePlaylist();
  }

  /// 清空播放列表 — 停止引擎，重置文件名，通知 UI 重建.
  ///
  /// Clears playlist — stops engine, resets filename, notifies UI.
  void clearPlaylist() {
    engine.stop();
    playlist.clear();
    currentFileName.value = '';
    _onNeedRebuild();
    savePlaylist();
  }

  /// 切换播放模式 — 在 LoopAll / LoopSingle / Shuffle 之间循环切换.
  ///
  /// Cycles play mode through LoopAll → LoopSingle → Shuffle.
  void togglePlayMode() {
    // 循环取模：index + 1 后对 PlayMode 枚举长度取模，实现循环切换
    final next = (playlist.mode.index + 1) % PlayMode.values.length;
    playlist.mode = PlayMode.values[next];
    _onNeedRebuild();
    SettingsStore.savePlayMode(playlist.mode.index);
  }

  // ── 生命周期 ──

  /// 初始化播放控制器 — 内部委托 stateManager + autoAdvance 完成初始化
  ///
  /// [settings] 可选：调用方已加载时传入，避免重复 IO。
  /// 使用 DebugProbe 包裹以记录初始化耗时。
  Future<void> init({AppSettings? settings}) => probe.measureAsync('init', () async {
    await stateManager.init(settings: settings);
    await autoAdvance.init();
    await _trackPreferenceService?.load();
  });

  /// 释放资源 — 按序释放 autoAdvance / stateManager / currentFileName / validationError.
  ///
  /// Disposes resources in order: autoAdvance, stateManager, trackPreference, currentFileName, validationError.
  void dispose() {
    autoAdvance.dispose();
    stateManager.dispose();
    // fire-and-forget 保存轨道偏好
    unawaited(
      _trackPreferenceService?.save().catchError(
        (Object e) => log.e('TrackPreferenceService.save failed: $e'),
      ),
    );
    currentFileName.dispose();
    fileOps.validationError.dispose();
  }
}
