/// 模块级概览：播放器功能组件 — MVVM 架构的 View 层
///
/// 本文件是 MVVM 模式中的 View 层，负责：
/// 1. 持有 [PlayerServices] 实例（DI 容器），管理其生命周期
/// 2. 管理 UI 状态：ready（初始化完成）、error（错误状态）、
///    dragHovering（拖拽悬停）、customBindings（自定义快捷键）
/// 3. 提供业务回调：文件选择、拖放、播放模式切换
/// 4. 组合 [PlayerScreen] —— 实际的播放器 UI
///
/// 与 [PlayerViewModel] 的区别：
/// - PlayerFeature 是 StatefulWidget，直接参与 Widget 树，持有 BuildContext
/// - PlayerViewModel 是 ChangeNotifier，不涉及 BuildContext，可独立测试
/// - 本文件同时承担 View 和部分 ViewModel 职责（历史遗留，后续重构目标）
///
/// 架构位置：App → DeferredPlayerFeature → **PlayerFeature** → PlayerScreen
/// 依赖链：PlayerFeature → PlayerServices → PlaybackController → FvpEngine
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/services/path_validator.dart';
import '../../kernel/utils/log.dart';
import '../../kernel/startup/startup_coordinator.dart';
import '../../ui/player/player_screen.dart';
import '../../ui/shared/empty_state.dart';
import '../../ui/shared/play_mode_utils.dart';
import '../../ui/shared/osd_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/services/video_processing_service.dart';
import '../../kernel/player_services.dart';

/// 播放器功能组件 — UI 状态管理 + PlayerScreen 组合
///
/// 作为 MVVM 的 View 层，[PlayerFeature] 负责：
/// - 创建并持有 [PlayerServices]（服务容器）
/// - 管理 UI 级状态：初始化就绪、错误信息、拖拽悬停、自定义快捷键
/// - 提供文件选择/拖放/播放模式切换等业务回调
/// - 在初始化完成后组合渲染 [PlayerScreen]
///
/// 需要 MaterialApp 级 [BuildContext] 的回调（设置面板、右键菜单）
/// 由上层 App 通过构造函数传入，避免 PlayerFeature 对全局 context 的直接依赖。
class PlayerFeature extends StatefulWidget {
  /// 启动协调器，用于上报初始化各阶段进度
  final StartupCoordinator coordinator;

  /// Win32 窗口桥接服务，用于全屏/窗口控制等原生操作
  final WindowBridge windowService;


  /// 打开设置面板的回调 — 需要 MaterialApp 级 BuildContext 和引擎/视频处理服务引用
  final void Function(
    BuildContext context,
    MediaEngine engine,
    VideoProcessingService videoProcessing, {
    ValueChanged<int>? onAudioTrackChanged,
  })
  onSettings;

  /// 右键快捷菜单回调 — 需要触发位置的 BuildContext 和 TapUpDetails 坐标
  final void Function(BuildContext barCtx, TapUpDetails details)
  onSettingsSecondary;

  const PlayerFeature({
    super.key,
    required this.coordinator,
    required this.windowService,
    required this.onSettings,
    required this.onSettingsSecondary,
  });

  @override
  State<PlayerFeature> createState() => _PlayerFeatureState();
}

class _PlayerFeatureState extends State<PlayerFeature> {
  /// 服务容器，持有 engine/playlist/controller/videoProcessing 等所有播放服务
  late final PlayerServices _services;

  /// 初始化是否完成（控制 build 渲染：未就绪时显示空 widget）
  bool _ready = false;

  /// 初始化是否出错（显示错误状态 UI）
  bool _error = false;

  /// 错误信息文本（显示在错误状态 UI 中）
  String _errorMessage = '';

  /// 是否处于文件拖拽悬停状态（控制拖拽提示 UI 显示）
  bool _isDragHovering = false;

  /// 从 SettingsStore 加载的自定义快捷键绑定（key: 快捷键名称, value: 按键组合）
  Map<String, String> _customBindings = {};

  @override
  void initState() {
    super.initState();
    // 创建服务容器（同步构造），然后异步初始化
    _services = PlayerServices(
      windowService: widget.windowService,
    );
    _init();
  }

  /// 异步初始化播放器服务
  ///
  /// 初始化序列：
  /// 1. 上报 StartupPhase.playerInit 开始（进度 0.0）
  /// 2. 调用 PlayerServices.init() — 创建引擎、播放列表、控制器、视频处理服务
  /// 3. 上报加载设置阶段（进度 0.7）
  /// 4. 从 SettingsStore 加载自定义快捷键绑定
  /// 5. 上报初始化完成，调用 coordinator.markReady()
  ///
  /// 错误处理：任何步骤失败都会捕获异常，设置 _error 状态显示错误 UI，
  /// 不会向上传播导致 App 崩溃。使用 Stopwatch 记录初始化耗时用于性能分析。
  Future<void> _init() async {
    final sw = Stopwatch()..start();
    widget.coordinator.report(
      StartupPhase.playerInit,
      0.0,
      'Initializing engine...',
    );
    try {
      await _services.init();
      widget.coordinator.report(
        StartupPhase.playerInit,
        0.7,
        'Loading settings...',
      );
      _customBindings = await SettingsStore.loadShortcuts();
    } catch (e, stackTrace) {
      log.e('[PlayerFeature] init failed: $e', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = '$e';
        });
      }
      return;
    }
    log.d('[PlayerFeature] init completed in ${sw.elapsedMilliseconds}ms');
    widget.coordinator.markReady();
    if (mounted) setState(() => _ready = true);
  }

  /// 打开文件选择器并播放选中的文件
  ///
  /// 使用 FilePicker 以 custom 模式打开系统文件选择器，
  /// allowedExtensions 覆盖视频格式（mp4/mkv/avi/mov 等）和音频格式
  /// （mp3/flac/wav/aac 等），确保用户只能选择播放器支持的文件类型。
  /// 选中的文件逐个通过 PlaybackController.openAndPlay() 打开播放。
  Future<void> _openFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: PathValidator.supportedExtensions,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          await _services.controller.openAndPlay(file.path!);
        }
      }
    }
  }

  /// 处理文件拖放事件 — 将拖入的文件路径添加到播放列表
  void _onFilesDropped(List<String> paths) {
    _services.controller.addFiles(paths);
  }

  /// 切换播放模式（循环全部 → 单曲循环 → 随机）并通过 OSD 显示当前模式
  ///
  /// 切换顺序由 PlaybackController.togglePlayMode() 内部的 PlayMode 枚举决定，
  /// OSD 显示使用 playModeLabel/playModeUtils 提供的本地化标签和图标。
  void _onTogglePlayMode() {
    _services.controller.togglePlayMode();
    final l10n = AppLocalizations.of(context);
    OsdService.I.show(
      playModeLabel(_services.playlist.mode, l10n),
      icon: playModeIcon(_services.playlist.mode),
    );
  }

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return _buildErrorState(context);
    if (!_ready) return const SizedBox.shrink();
    return _buildPlayerScreen();
  }

  /// 构建错误状态 UI — 显示错误图标、本地化错误标题和详细错误信息
  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).playerInitFailed,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建播放器主界面 — 将 PlayerServices 中的各项服务注入 PlayerScreen
  ///
  /// 服务注入关系：engine → 渲染、controller → 播放控制、playlist → 播放列表。
  /// customBindings 从 SettingsStore 加载的自定义快捷键。
  /// playlistGeneration 是一个 ValueNotifier，每次播放列表变化时递增，
  /// 触发 PlayerScreen 通过 ValueListenableBuilder 重建。
  ///
  /// 注意：这里有一行 debugDumpApp() 调用，仅在 debug 模式下执行，
  /// 用于首帧渲染后 dump widget 树结构，帮助调试布局问题。
  Widget _buildPlayerScreen() {
    final engine = _services.engine;
    final controller = _services.controller;
    final playlist = _services.playlist;

    // DEBUG: 首帧渲染后 dump widget 树，帮助调试布局结构（仅 debug 模式生效）
    assert(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugDumpApp();
      });
      return true;
    }());

    return PlayerScreen(
      engine: engine,
      controller: controller,
      playlist: playlist,
      customBindings: _customBindings,
      playlistGeneration: _services.playlistGeneration,
      windowService: _services.windowService,
      onOpenFile: _openFile,
      onTogglePlayMode: _onTogglePlayMode,
      onSettings: () => widget.onSettings(
        context,
        _services.engine,
        _services.videoProcessing,
        onAudioTrackChanged:
            _services.controller.trackPreferenceService?.recordAudioTrack,
      ),
      onSettingsSecondary: widget.onSettingsSecondary,
      onFilesDropped: _onFilesDropped,
      onDragHoverChanged: (hovering) {
        setState(() => _isDragHovering = hovering);
      },
      onFolderScanned: (folderPath, scanned) {
        playlist.addAll(scanned.map((i) => i.path).toList());
        _services.playlistGeneration.value++;
      },
      onClearHistory: () {
        final keptPaths = playlist.items
            .where((i) => (i.timestamp ?? 0) == 0)
            .map((i) => i.path)
            .toList();
        playlist.clear();
        playlist.addAll(keptPaths);
        _services.playlistGeneration.value++;
      },
      emptyState: EmptyState(
        onOpenFile: _openFile,
        isDragHovering: _isDragHovering,
        engineState: engine.state,
      ),
    );
  }
}
