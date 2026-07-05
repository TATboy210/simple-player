/// 模块级概览：播放器服务容器 — 依赖注入与生命周期管理
///
/// 本文件实现了播放器的服务容器模式，负责：
/// 1. 创建并持有所有播放服务实例（Engine、Playlist、PlaybackController、VideoProcessingService）
/// 2. 提供 init/dispose 生命周期管理
/// 3. 通过 engineOverride 支持调试模式下的 MockEngine 注入
///
/// 设计原则：
/// - 单一职责：只负责服务的创建、初始化和销毁，不涉及 UI 状态
/// - 依赖注入：所有服务通过构造函数或 init() 注入，便于测试时替换
/// - 生命周期一致：dispose 顺序与 init 相反（playlistGeneration → window → videoProcessing → controller → engine）
///
/// 架构位置：PlayerFeature/PlayerViewModel → **PlayerServices** → 各具体服务
/// 依赖链：PlayerServices → FvpEngine → fvp/MDK 原生库
library;

import 'package:flutter/foundation.dart';
import '../../kernel/engine/engine_state.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/fvp_engine.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/playlist/playlist.dart';
import 'services/playback_controller.dart';
import 'services/video_processing_service.dart';

/// 播放器服务容器 — 创建并管理所有播放服务的生命周期
///
/// [PlayerServices] 是播放器核心服务的 DI 容器，持有以下服务实例：
/// - [EngineState] (engine) — 视频渲染引擎（FvpEngine 或 MockEngine）
/// - [Playlist] (playlist) — 播放列表管理
/// - [PlaybackController] (controller) — 播放控制编排器
/// - [VideoProcessingService] (videoProcessing) — 视频处理（亮度/对比度/旋转等）
/// - [WindowBridge] (windowService) — Win32 窗口桥接
///
/// 不涉及 UI 状态，不涉及 BuildContext — 可独立于 Widget 树进行单元测试。
class PlayerServices {
  PlayerServices({required this.windowService, this.engineOverride});

  /// 异步创建并初始化 PlayerServices 实例
  ///
  /// 使用静态工厂方法而非构造函数，因为 init() 包含异步操作
  /// （SettingsStore.load()），Dart 构造函数不支持 async。
  /// 创建流程：构造 → init() → 返回已初始化的实例。
  static Future<PlayerServices> create({
    required WindowBridge windowService,
    EngineState? engineOverride,
  }) async {
    final services = PlayerServices(
      windowService: windowService,
      engineOverride: engineOverride,
    );
    await services.init();
    return services;
  }

  /// 可选的引擎覆盖 — 调试模式下注入 MockEngine 替代 FvpEngine
  ///
  /// 传递此参数时，init() 会使用覆盖引擎而非创建新的 FvpEngine。
  /// 用于单元测试和 Widget 测试中模拟引擎行为。
  final EngineState? engineOverride;

  /// 视频渲染引擎实例（FvpEngine 或 engineOverride）
  late final EngineState engine;

  /// 播放列表管理器
  late final Playlist playlist;

  /// 播放控制编排器 — 编排 engine + playlist 的交互
  late final PlaybackController controller;

  /// 视频处理服务 — 亮度/对比度/饱和度/色调/旋转/宽高比/去隔行
  late final VideoProcessingService videoProcessing;

  /// Win32 窗口桥接服务
  final WindowBridge windowService;

  /// 播放列表版本号 — 每次播放列表变化时递增，触发 UI 重建
  ///
  /// 使用 `ValueNotifier<int>` 而非 `ValueNotifier<Playlist>`，
  /// 因为只需通知"列表已变化"，UI 通过 playlist.items 获取最新数据。
  /// 这是一个轻量级的变更通知机制，避免不必要的深拷贝。
  final ValueNotifier<int> playlistGeneration = ValueNotifier(0);

  /// 初始化所有播放服务
  ///
  /// 初始化顺序：
  /// 1. 创建引擎（FvpEngine 或 engineOverride）
  /// 2. 创建播放列表
  /// 3. 创建 PlaybackController 并注入 engine + playlist
  /// 4. 从 SettingsStore 加载设置并传递给 controller
  /// 5. 创建 VideoProcessingService 并注入 engine + settings
  ///
  /// 每个服务的创建都依赖前一个服务的结果，因此必须顺序执行。
  Future<void> init() async {
    engine = engineOverride ?? FvpEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => playlistGeneration.value++,
    );
    final settings = await SettingsStore.load();
    await controller.init(settings: settings);
    videoProcessing = VideoProcessingService(engine, initialSettings: settings);
  }

  /// 释放所有服务资源
  ///
  /// 释放顺序与 init() 相反（playlistGeneration → window → videoProcessing → controller → engine），
  /// 确保被依赖的服务后释放。每个 dispose() 都是幂等的（多次调用安全）。
  void dispose() {
    playlistGeneration.dispose();
    windowService.dispose();
    videoProcessing.dispose();
    controller.dispose();
    engine.dispose();
  }
}
