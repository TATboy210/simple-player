/// Services 层播放控制模块 — 门面模式统一入口
///
/// 本文件实现 [PlaybackController] 作为播放器运行时能力的统一门面，
/// 组合 [PlaybackNavigator] / [FileOperations] / [StateMonitor] 三个子模块，
/// UI 层只与本类交互，不直接访问子模块。
///
/// 架构位置：PlayerViewModel → **PlaybackController** → PlaybackNavigator / FileOperations / StateMonitor → EngineState
/// 设计模式：Facade（门面模式）— 简化 UI 层对多个子模块的调用路径
library;

import 'package:flutter/foundation.dart';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/utils/debug_probe.dart';
import 'file_operations.dart';
import 'playback_navigator.dart';
import 'state_monitor.dart';
import 'subtitle_service.dart';

/// 播放控制器 — 播放器全部运行时能力的统一门面入口
///
/// 组合 [PlaybackNavigator] / [FileOperations] / [StateMonitor] 三个子模块，
/// UI 层只与本类交互。所有子模块通过 [PlaybackContract] 接口访问共享依赖。
///
/// 职责划分：
/// - 播放导航：委托 [PlaybackNavigator]（playIndex / playNext / playPrevious）
/// - 文件操作：委托 [FileOperations]（openAndPlay / addFiles）
/// - 状态监控：委托 [StateMonitor]（初始化 / 状态监听 / 销毁保存）
/// - 播放列表 CRUD：直接管理 removeAt / reorder / clearPlaylist / togglePlayMode
///
/// 生命周期：init() → 使用 → dispose()
/// init() 内部调用 StateMonitor.init()，触发设置恢复和状态监听注册。
class PlaybackController {
  PlaybackController({
    required this.engine,
    required this.playlist,
    required VoidCallback onNeedRebuild,
    void Function(Object error)? onError,
    SubtitleService? subtitleService,
  }) : _onNeedRebuild = onNeedRebuild,
       _onError = onError,
       _subtitleService = subtitleService {
    navigator = PlaybackNavigator(this);
    fileOps = FileOperations(this);
    monitor = StateMonitor(this);
  }

  /// 视频渲染引擎实例（FvpEngine 或 MockEngine）
  final EngineState engine;

  /// 播放列表管理器 — 包含当前播放索引、播放模式、历史记录
  final Playlist playlist;

  /// UI 重建回调 — 子模块播放列表变更时调用
  final VoidCallback _onNeedRebuild;

  /// 错误回调 — 子模块捕获异常时调用（null 表示忽略错误）
  final void Function(Object error)? _onError;

  /// 字幕服务 — 可选依赖，null 表示无外挂字幕支持
  final SubtitleService? _subtitleService;

  /// 播放导航子模块 — 索引跳转和并发 open() 守卫
  late final PlaybackNavigator navigator;

  /// 文件操作子模块 — 文件打开和批量添加
  late final FileOperations fileOps;

  /// 状态监控子模块 — 断点保存、设置恢复、自动连播
  late final StateMonitor monitor;

  /// 调试探针 — 记录播放控制操作的耗时和事件（编译时开关 kDebugMode）
  final DebugProbe probe = DebugProbeRegistry.register('playback');

  /// 当前播放文件名（仅文件名，不含路径）— UI 层显示标题栏文件名
  final ValueNotifier<String> currentFileName = ValueNotifier('');

  /// 通知 UI 层播放列表已变更
  void onNeedRebuild() => _onNeedRebuild();

  /// 错误回调（子模块通过 `_rt.onError?.call(e)` 调用）
  void Function(Object error)? get onError => _onError;

  /// 获取字幕服务（可能为 null）
  SubtitleService? get subtitleService => _subtitleService;

  /// 保存播放列表 — 异步写入，跨模块共享
  void savePlaylist() {
    PlaylistStore.save(playlist);
  }

  // ── 转发 — UI 层的统一入口 ──
  // 所有播放/文件操作委托给对应子模块，UI 层无需关心具体实现。

  /// 播放指定索引 — 委托 [PlaybackNavigator.playIndex]
  Future<void> playIndex(int i) => navigator.playIndex(i);

  /// 播放下一首 — 委托 [PlaybackNavigator.playNext]
  Future<void> playNext() => navigator.playNext();

  /// 播放上一首 — 委托 [PlaybackNavigator.playPrevious]
  Future<void> playPrevious() => navigator.playPrevious();

  /// 打开并播放文件 — 委托 [FileOperations.openAndPlay]
  Future<bool> openAndPlay(String p) => fileOps.openAndPlay(p);

  /// 批量添加文件 — 委托 [FileOperations.addFiles]
  Future<int> addFiles(List<String> p) => fileOps.addFiles(p);

  /// 最近一次路径校验错误（null 表示无错误）— 委托 [FileOperations.validationError]
  ValueNotifier<String?> get validationError => fileOps.validationError;

  // ── 播放列表 CRUD（从 StateMonitor 提取）──

  /// 移除播放列表中指定索引
  ///
  /// 如果移除的是当前播放项，自动停止引擎并尝试播放下一项。
  /// 移除后通知 UI 重建并持久化播放列表。
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

  /// 拖拽排序 — 交换播放列表中两个位置的项
  void reorder(int oldIndex, int newIndex) {
    playlist.reorder(oldIndex, newIndex);
    _onNeedRebuild();
    savePlaylist();
  }

  /// 清空播放列表 — 停止引擎，重置文件名，通知 UI 重建
  void clearPlaylist() {
    engine.stop();
    playlist.clear();
    currentFileName.value = '';
    _onNeedRebuild();
    savePlaylist();
  }

  /// 切换播放模式 — 在 LoopAll / LoopSingle / Shuffle 之间循环切换
  void togglePlayMode() {
    // 循环取模：index + 1 后对 PlayMode 枚举长度取模，实现循环切换
    final next = (playlist.mode.index + 1) % PlayMode.values.length;
    playlist.mode = PlayMode.values[next];
    _onNeedRebuild();
    SettingsStore.savePlayMode(playlist.mode.index);
  }

  // ── 生命周期 ──

  /// 初始化播放控制器 — 内部委托 StateMonitor 完成设置恢复和状态监听注册
  ///
  /// [settings] 可选：调用方已加载时传入，避免重复 IO。
  /// 使用 DebugProbe 包裹以记录初始化耗时。
  Future<void> init({AppSettings? settings}) =>
      probe.measureAsync('init', () => monitor.init(settings: settings));

  /// 释放资源 — 按序释放 StateMonitor / currentFileName / validationError
  void dispose() {
    monitor.dispose();
    currentFileName.dispose();
    fileOps.validationError.dispose();
  }
}
