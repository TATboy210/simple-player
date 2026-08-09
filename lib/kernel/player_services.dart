/// 播放器服务容器 — 依赖注入与生命周期管理.
///
/// Player service container — dependency injection and lifecycle management.
///
/// Implements the service container pattern:
/// 1. Creates and owns all playback service instances (Engine,
///    PlaybackController, VideoProcessingService).
/// 2. Provides init/dispose lifecycle management.
///
/// Design principles:
/// - Single responsibility: only creates, initializes, and destroys services;
///   no UI state involvement.
/// - Dependency injection: all services injected via constructor or [init],
///   replaceable in tests.
/// - Reverse-order disposal: dispose order is the reverse of init
///   (window → videoProcessing → controller → engine).
///
/// Architecture: PlayerFeature/PlayerViewModel → **PlayerServices** → concrete services.
/// Dependency chain: PlayerServices → MediaKitEngine → media_kit/libmpv native.
///
/// v1.8:移除 Playlist/playlistGeneration(单文件播放器,无队列)。
library;

import 'package:media_kit_video/media_kit_video.dart';
import 'diagnostics/clock.dart';
import 'diagnostics/kernel_logger.dart';
import 'diagnostics/memory_monitor.dart';
import 'diagnostics/rss_provider.dart';

import 'bridge/window_bridge.dart';
import 'engine/media_engine.dart';
import 'engine/media_kit_engine.dart';
import 'persistence/settings_store.dart';
import 'services/playback_controller.dart';
import 'services/video_processing_service.dart';

/// 播放器服务容器 — 创建并管理所有播放服务的生命周期.
///
/// DI container for core playback services. Holds:
/// - [engine] — media rendering engine ([MediaEngine])
/// - [controller] — playback orchestrator ([PlaybackController])
/// - [videoProcessing] — video effects ([VideoProcessingService])
/// - [windowService] — Win32 window bridge ([WindowBridge])
///
/// No UI state, no BuildContext — independently unit-testable.
class PlayerServices {
  PlayerServices({required this.windowService});

  /// 异步创建并初始化 PlayerServices 实例.
  ///
  /// Async factory — creates and fully initializes a [PlayerServices] instance.
  /// Static factory pattern because Dart constructors cannot be async;
  /// [init] involves `SettingsStore.load()` (async I/O).
  static Future<PlayerServices> create({
    required WindowBridge windowService,
  }) async {
    final services = PlayerServices(windowService: windowService);
    await services.init();
    return services;
  }

  /// 视频渲染引擎实例.
  ///
  /// Media rendering engine (media_kit/libmpv wrapper).
  late final MediaEngine engine;

  /// 播放控制编排器 — 单文件播放器门面.
  ///
  /// Playback orchestrator — single-file player facade.
  late final PlaybackController controller;

  /// 视频处理服务 — 亮度/对比度/饱和度/色调/旋转/宽高比/去隔行.
  ///
  /// Video processing — brightness, contrast, saturation, hue, rotation,
  /// aspect ratio, deinterlace.
  late final VideoProcessingService videoProcessing;

  /// Win32 窗口桥接服务.
  ///
  /// Win32 window bridge service.
  final WindowBridge windowService;

  /// media_kit [VideoController] — 供 UI [Video] widget 使用.
  ///
  /// 透传自 [_mediaKitEngine]. media_kit 是唯一后端 (fvp/MDK 已移除).
  VideoController get mediaKitVideoController =>
      _mediaKitEngine.videoController;

  /// media_kit 引擎实例 — 持有以透传 [mediaKitVideoController].
  late final MediaKitEngine _mediaKitEngine;

  /// 初始化所有播放服务.
  ///
  /// Initialization order (sequential — each step depends on the previous):
  /// 1. KernelLogger + MemoryMonitor (diagnostics)
  /// 2. MediaKitEngine (engine)
  /// 3. PlaybackController (orchestration)
  /// 4. SettingsStore.load() → controller.init(settings)
  /// 5. VideoProcessingService (video effects)
  Future<void> init() async {
    // Phase 17: 初始化 KernelLogger 静态实例 — 必须在引擎创建以前,
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

    // media_kit 是唯一后端 (fvp/MDK + KernelAdapter 临时层已移除).
    // 直接实例化 MediaKitEngine; engine 字段类型 MediaEngine,
    // MediaKitEngine implements MediaEngine, 45 消费方零改动.
    // diagnostics 经静态访问器 (KernelLoggerImpl.I / MemoryMonitor.I) 读取,
    // 无需 bundle 注入 (MediaKitEngine 构造函数不接 bundle).
    _mediaKitEngine = MediaKitEngine();
    engine = _mediaKitEngine;

    // v1.8:PlaybackController 不再接 playlist/onNeedRebuild(单文件播放器).
    controller = PlaybackController(engine: engine);
    final settings = await SettingsStore.load();
    await controller.init(settings: settings);
    videoProcessing = VideoProcessingService(engine, initialSettings: settings);
  }

  /// 释放所有服务资源.
  ///
  /// Disposes all services in reverse init order
  /// (window → videoProcessing → controller → engine),
  /// ensuring dependents are released before their dependencies.
  /// Each dispose is idempotent (safe to call multiple times).
  void dispose() {
    windowService.dispose();
    videoProcessing.dispose();
    controller.dispose();
    engine.dispose();
    // 释放 MemoryMonitor 静态实例 — cancel 其 Timer.periodic(30s),
    // 防止引擎 dispose 后定时器继续运行泄漏 (对称 init 中的 MemoryMonitor.init)。
    MemoryMonitor.disposeStatic();
  }
}
