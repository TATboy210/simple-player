/// 模块级概览：播放器服务容器 — 依赖注入与生命周期管理
///
/// 本文件实现了播放器的服务容器模式，负责：
/// 1. 创建并持有所有播放服务实例（Engine、Playlist、PlaybackController、VideoProcessingService）
/// 2. 提供 init/dispose 生命周期管理
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
import 'diagnostics/clock.dart';
import 'diagnostics/diagnostics_bundle.dart';
import 'diagnostics/event_log_slot.dart';
import 'diagnostics/kernel_logger.dart';
import 'diagnostics/memory_monitor.dart';
import 'diagnostics/metrics_slot.dart';
import 'diagnostics/rss_provider.dart';
import 'engine/engine_state.dart';

import 'adapter/kernel_adapter.dart';
import 'bridge/window_bridge.dart';
import 'engine/fvp_engine.dart';
import 'persistence/settings_store.dart';
import 'playlist/playlist.dart';
import 'services/playback_controller.dart';
import 'services/video_processing_service.dart';

/// 播放器服务容器 — 创建并管理所有播放服务的生命周期
///
/// [PlayerServices] 是播放器核心服务的 DI 容器，持有以下服务实例：
/// - [MediaEngine] (engine) — 视频渲染引擎
/// - [Playlist] (playlist) — 播放列表管理
/// - [PlaybackController] (controller) — 播放控制编排器
/// - [VideoProcessingService] (videoProcessing) — 视频处理（亮度/对比度/旋转等）
/// - [WindowBridge] (windowService) — Win32 窗口桥接
///
/// 不涉及 UI 状态，不涉及 BuildContext — 可独立于 Widget 树进行单元测试。
class PlayerServices {
  PlayerServices({required this.windowService});

  /// 异步创建并初始化 PlayerServices 实例
  ///
  /// 使用静态工厂方法而非构造函数，因为 init() 包含异步操作
  /// （SettingsStore.load()），Dart 构造函数不支持 async。
  /// 创建流程：构造 → init() → 返回已初始化的实例。
  static Future<PlayerServices> create({
    required WindowBridge windowService,
  }) async {
    final services = PlayerServices(
      windowService: windowService,
    );
    await services.init();
    return services;
  }

  /// 视频渲染引擎实例
  late final MediaEngine engine;

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
  /// 1. 创建引擎（FvpEngine）
  /// 2. 创建播放列表
  /// 3. 创建 PlaybackController 并注入 engine + playlist
  /// 4. 从 SettingsStore 加载设置并传递给 controller
  /// 5. 创建 VideoProcessingService 并注入 engine + settings
  ///
  /// 每个服务的创建都依赖前一个服务的结果，因此必须顺序执行。
  Future<void> init() async {
    // Phase 17: 初始化 KernelLogger 静态实例 — 必须在 FvpEngine 创建之前,
    // 确保所有内核代码从启动第一刻起就能通过 KernelLoggerImpl.I 输出日志。
    // kDebugMode 门控: debug 模式 CompositeSink([DebugPrintSink, DevToolsSink]),
    // release 模式 NullSink (零输出, 可 tree-shake)。
    KernelLoggerImpl.init();

    // Phase 19: 创建实例化 MemoryMonitor 并设置静态 I 访问器,
    // 使 DebugExporter 等遗留调用点可通过 MemoryMonitor.I.snapshot() 访问。
    final memoryMonitor = MemoryMonitor(
      rssProvider: const ProcessInfoRssProvider(),
      clock: const SystemClock(),
      logger: KernelLoggerImpl.I,
    );
    MemoryMonitor.init(memoryMonitor);

    // Strangler Fig seam (Phase 16, ADAPT-01/02): 用 KernelAdapter 包裹同一个
    // FvpEngine 实例，legacy/migrated 均指向它 (D13/D19 — NewFvpEngine 尚不存在，
    // 零额外原生资源)。policy 全量路由到 legacy，行为与直接使用 FvpEngine 完全
    // 一致；bundle 传递真实 KernelLogger + 真实 MemoryMonitor，其余 2 插槽 noop (P20 激活)。
    // Phase 20 将把 migrated 换成 NewFvpEngine 并翻转 policy，此处即为切换点。
    final fvp = FvpEngine();
    final bundle = DiagnosticsBundle(
      logger: KernelLoggerImpl.I,
      memoryMonitor: memoryMonitor,
      metrics: const NullMetricsSlot(),
      eventLog: const NullEventLogSlot(),
    );
    engine = KernelAdapter(
      legacy: fvp,
      migrated: fvp,
      policy: const DelegationPolicy.all(KernelMode.legacy),
      bundle: bundle,
    );
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
