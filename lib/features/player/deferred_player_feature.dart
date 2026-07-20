/// 模块级概览：延迟加载播放器功能组件
///
/// 本文件实现了 Dart 的 `deferred as` 延迟加载模式，将 PlayerFeature
/// 模块推迟到首次 build 时异步加载。这样做的原因是：
///
/// 1. 避免在 App 启动时 eager 导入 FvpEngine、Playlist 等重型类型，
///    这些类型依赖 fvp/MDK 原生库，延迟加载可以缩短首屏渲染时间。
/// 2. 加载失败时可以独立显示错误状态，不影响 App 其他部分的运行。
/// 3. StartupCoordinator 在加载各阶段上报进度，Splash 由 App 层驱动。
///
/// 架构位置：App 层 → DeferredPlayerFeature → PlayerFeature（延迟加载）。
/// DeferredPlayerFeature 是 PlayerFeature 的薄包装，只负责异步加载和
/// 加载状态管理（loading / loaded / error），不持有任何业务逻辑。
library;

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../kernel/startup/startup_coordinator.dart';
import '../../l10n/app_localizations.dart';
import 'player_feature.dart' deferred as player_feature;
import '../../kernel/services/video_processing_service.dart';

/// 延迟加载的播放器功能组件 — deferred import 包装器
///
/// 使用 Dart `deferred as` 机制延迟加载 [PlayerFeature] 模块。
/// 在 widget 首次 build 时触发异步加载，加载期间上报进度到
/// [StartupCoordinator]，加载完成后重建并渲染 [PlayerFeature]。
///
/// 错误处理策略：加载失败时显示本地化的错误文本，不会导致 App 崩溃。
/// 回调参数使用抽象类型 [EngineStateView]，避免对具体引擎实现的依赖。
class DeferredPlayerFeature extends StatefulWidget {
  /// 启动协调器，用于上报各阶段加载进度
  final StartupCoordinator coordinator;

  /// 窗口桥接服务，传递给 PlayerFeature 用于 Win32 窗口控制
  final WindowBridge windowService;


  /// 打开设置面板的回调（需要 MaterialApp 级 BuildContext）
  final void Function(
    BuildContext context,
    MediaEngine engine,
    VideoProcessingService? videoProcessing, {
    ValueChanged<int>? onAudioTrackChanged,
  })
  onSettings;

  /// 右键快捷菜单回调（需要触发位置的 BuildContext 和 TapUpDetails）
  final void Function(BuildContext barCtx, TapUpDetails details)
  onSettingsSecondary;

  const DeferredPlayerFeature({
    super.key,
    required this.coordinator,
    required this.windowService,
    required this.onSettings,
    required this.onSettingsSecondary,
  });

  @override
  State<DeferredPlayerFeature> createState() => _DeferredPlayerFeatureState();
}

class _DeferredPlayerFeatureState extends State<DeferredPlayerFeature> {
  /// 延迟模块是否已加载完成
  bool _loaded = false;

  /// 加载是否失败（显示错误状态）
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  /// 异步加载延迟模块库
  ///
  /// 加载流程：
  /// 1. 向 StartupCoordinator 上报 playerModule 阶段开始（进度 0.0）
  /// 2. 调用 `player_feature.loadLibrary()` 触发 Dart 编译器的延迟加载解析
  ///    — 这是 `deferred as` 导入的关键步骤，运行时首次调用会下载并链接模块
  /// 3. 加载成功后上报完成（进度 1.0），设置 _loaded = true 触发重建
  /// 4. 加载失败时记录错误日志，设置 _error = true 显示错误 UI
  ///
  /// 注意：每次 build 都检查 mounted 状态，避免在 widget 已销毁后调用 setState
  Future<void> _loadLibrary() async {
    widget.coordinator.report(
      StartupPhase.playerModule,
      0.0,
      'Loading player module...',
    );
    try {
      // 触发 deferred import 的运行时解析 — 加载 PlayerFeature 所在的子库
      await player_feature.loadLibrary();
      widget.coordinator.report(
        StartupPhase.playerModule,
        1.0,
        'Player module loaded',
      );
      if (mounted) setState(() => _loaded = true);
    } catch (e, stackTrace) {
      KernelLogger.I.e(
        '[DeferredPlayerFeature] loadLibrary failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: Text(
          AppLocalizations.of(context).playerLoadError,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_loaded) {
      return const SizedBox.shrink();
    }
    return player_feature.PlayerFeature(
      coordinator: widget.coordinator,
      windowService: widget.windowService,
      onSettings: widget.onSettings,
      onSettingsSecondary: widget.onSettingsSecondary,
    );
  }
}
