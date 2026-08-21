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

import 'window_bridge/window_manager_service.dart';
import 'engine/media_engine.dart';
import 'engine/media_kit_engine.dart';
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
  /// [init] 只初始化运行时服务，不执行用户设置 I/O。
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
  MediaEngine? _engine;

  MediaEngine get engine => _engine!;

  /// 播放控制编排器 — 单文件播放器门面.
  ///
  /// Playback orchestrator — single-file player facade.
  PlaybackController? _controller;

  PlaybackController get controller => _controller!;

  /// 视频处理服务 — 亮度/对比度/饱和度/色调/旋转/宽高比/去隔行.
  ///
  /// Video processing — brightness, contrast, saturation, hue, rotation,
  /// aspect ratio, deinterlace.
  VideoProcessingService? _videoProcessing;

  VideoProcessingService get videoProcessing => _videoProcessing!;

  /// Win32 窗口桥接服务.
  ///
  /// Win32 window bridge service.
  final WindowBridge windowService;

  /// media_kit [VideoController] — 供 UI [Video] widget 使用.
  ///
  /// 透传自 [_mediaKitEngine]. media_kit 是唯一后端 (fvp/MDK 已移除).
  VideoController get mediaKitVideoController =>
      _mediaKitEngine!.videoController;

  /// media_kit 引擎实例 — 持有以透传 [mediaKitVideoController].
  MediaKitEngine? _mediaKitEngine;

  bool _initialized = false;
  bool _disposed = false;
  bool _engineCreated = false;
  bool _controllerCreated = false;
  bool _videoProcessingCreated = false;
  Future<void>? _initOperation;

  /// 初始化所有播放服务.
  ///
  /// Initialization order (sequential — each step depends on the previous):
  /// 1. KernelLogger + MemoryMonitor (diagnostics)
  /// 2. MediaKitEngine (engine)
  /// 3. PlaybackController (orchestration)
  /// 4. controller.init() → 运行时默认状态
  /// 5. VideoProcessingService (video effects)
  Future<void> init() {
    if (_disposed) return Future<void>.value();
    if (_initialized) return Future<void>.value();
    return _initOperation ??= _initOnce();
  }

  Future<void> _initOnce() async {
    try {
      KernelLoggerImpl.init();
      final memoryMonitor = MemoryMonitor(
        rssProvider: const ProcessInfoRssProvider(),
        clock: const SystemClock(),
        logger: KernelLoggerImpl.I,
      );
      MemoryMonitor.init(memoryMonitor);

      _throwIfDisposed();
      _mediaKitEngine = MediaKitEngine();
      _engine = _mediaKitEngine;
      _engineCreated = true;

      _throwIfDisposed();
      _controller = PlaybackController(engine: engine);
      _controllerCreated = true;
      await controller.init();
      if (_disposed) throw StateError('PlayerServices disposed during init');

      _throwIfDisposed();
      _videoProcessing = VideoProcessingService(engine);
      _videoProcessingCreated = true;
      _initialized = true;
    } catch (_) {
      // Cleanup must be best-effort: a failure in one disposer must not mask
      // the initialization error or prevent dependent resources from closing.
      _disposeCreatedResources();
      _videoProcessing = null;
      _controller = null;
      _engine = null;
      _mediaKitEngine = null;
      rethrow;
    } finally {
      _initOperation = null;
    }
  }

  void _throwIfDisposed() {
    if (_disposed) throw StateError('PlayerServices disposed during init');
  }

  void _disposeCreatedResources() {
    if (_videoProcessingCreated) _disposeSafely(_videoProcessing?.dispose);
    if (_controllerCreated) _disposeSafely(_controller?.dispose);
    if (_engineCreated) _disposeSafely(_engine?.dispose);
    MemoryMonitor.disposeStatic();
    _videoProcessingCreated = false;
    _controllerCreated = false;
    _engineCreated = false;
  }

  void _disposeSafely(void Function()? disposer) {
    if (disposer == null) return;
    try {
      disposer();
    } on Object catch (_) {
      // Preserve the original init failure while continuing reverse cleanup.
    }
  }

  /// 释放所有服务资源.
  ///
  /// Disposes all services in reverse init order
  /// (window → videoProcessing → controller → engine),
  /// ensuring dependents are released before their dependencies.
  /// Each dispose is idempotent (safe to call multiple times).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // The in-flight init observes this flag after each await and rolls back
    // resources before publishing a ready service. dispose remains synchronous
    // to preserve the existing composition-root contract.
    // WindowBridge is borrowed from the composition root; PlayerServices must
    // never dispose a dependency it did not create. If init is awaiting an
    // async dependency, let its catch/finally path perform rollback so dispose
    // cannot race the same resource teardown.
    if (_initOperation == null) {
      _disposeCreatedResources();
    }
  }
}
