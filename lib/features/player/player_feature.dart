/// 模块级概览：播放器功能组件 — MVVM 架构的 View 层
///
/// 本文件是 MVVM 模式中的 View 层，负责：
/// 1. 持有 [PlayerServices] 实例（DI 容器），管理其生命周期
/// 2. 管理 UI 状态：ready（初始化完成）、error（错误状态）、
///    dragHovering（拖拽悬停）、customBindings（自定义快捷键）
/// 3. 提供业务回调：文件选择与单文件拖放
/// 4. 组合 [PlayerScreen] —— 实际的播放器 UI
///
/// 与 [PlayerViewModel] 的区别：
/// - PlayerFeature 是 StatefulWidget，直接参与 Widget 树，持有 BuildContext
/// - PlayerViewModel 是 ChangeNotifier，不涉及 BuildContext，可独立测试
/// - 本文件同时承担 View 和部分 ViewModel 职责（历史遗留，后续重构目标）
///
/// 架构位置：App → **PlayerFeature** → PlayerScreen（启动链两层直挂，见 app.dart）
/// 依赖链：PlayerFeature → PlayerServices → PlaybackController → MediaKitEngine
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../kernel/window_bridge/window_manager_service.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../kernel/diagnostics/startup_timeline.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/player_services.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/player/player_screen.dart';
import '../../ui/shared/empty_state.dart';
import 'file_picker_adapters.dart';
import 'file_picker_coordinator.dart';

/// 播放器功能组件 — UI 状态管理 + PlayerScreen 组合
///
/// 作为 MVVM 的 View 层，[PlayerFeature] 负责：
/// - 创建并持有 [PlayerServices]（服务容器）
/// - 管理 UI 级状态：初始化就绪、错误信息、拖拽悬停、自定义快捷键
/// - 提供文件选择与单文件拖放回调
/// - 在初始化完成后组合渲染 [PlayerScreen]
///
/// 需要 MaterialApp 级 [BuildContext] 的回调（设置面板、右键菜单）
/// 由上层 App 通过构造函数传入，避免 PlayerFeature 对全局 context 的直接依赖。
class PlayerFeature extends StatefulWidget {
  /// 启动计时器 — 服务初始化完成后由本组件打点并输出 Timeline 日志。
  final StartupTimeline startupTimeline;

  /// Win32 窗口桥接服务，用于全屏/窗口控制等原生操作
  final WindowBridge windowService;

  const PlayerFeature({
    super.key,
    required this.startupTimeline,
    required this.windowService,
  });

  @override
  State<PlayerFeature> createState() => _PlayerFeatureState();
}

class _PlayerFeatureState extends State<PlayerFeature> {
  /// 服务容器，持有 engine/controller/videoProcessing 等播放服务
  late final PlayerServices _services;

  /// 单开系统文件选择器会话及其 attention 协调器。
  late final FilePickerCoordinator _filePickerCoordinator;

  /// 设置面板控制器 — 由组合根构造，传入 PlayerScreen 挂载覆盖层壳（D-02）

  /// 初始化是否完成（控制 build 渲染：未就绪时显示空 widget）
  bool _ready = false;

  /// 初始化是否出错（显示错误状态 UI）
  bool _error = false;

  /// 错误信息文本（显示在错误状态 UI 中）
  String _errorMessage = '';

  /// 是否处于文件拖拽悬停状态（控制拖拽提示 UI 显示）
  bool _isDragHovering = false;

  /// 内置快捷键映射，移除用户设置后不再从磁盘读取。
  static const Map<String, String> _customBindings = {};

  @override
  void initState() {
    super.initState();
    // 创建服务容器（同步构造），然后异步初始化
    _services = PlayerServices(windowService: widget.windowService);
    _filePickerCoordinator = FilePickerCoordinator(
      picker: const FilePickerMediaGateway(),
      attention: const MethodChannelFilePickerAttention(),
      openAndPlay: (path) async {
        await _services.controller.openAndPlay(path);
      },
    );
    _init();
  }

  /// 异步初始化播放器服务
  ///
  /// 初始化序列：
  /// 1. 调用 PlayerServices.init() — 初始化引擎、控制器与视频处理服务
  /// 2. 恢复播放列表 (v0.0.5) — 从磁盘读队列/断点/模式, 不装载不自动播
  /// 3. 打点 playerInit 并输出启动 Timeline 日志
  ///
  /// 错误处理：任何步骤失败都会捕获异常，设置 _error 状态显示错误 UI，
  /// 不会向上传播导致 App 崩溃。使用 Stopwatch 记录初始化耗时用于性能分析。
  Future<void> _init() async {
    final sw = Stopwatch()..start();
    try {
      await _services.init();
      // 恢复失败仅记日志 (store 内部已容错), 不阻断初始化.
      await _services.playlistCoordinator.restoreFromDisk();
    } catch (e, stackTrace) {
      KernelLogger.I.e(
        '[PlayerFeature] init failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = '$e';
        });
      }
      return;
    }
    KernelLogger.I.d(
      '[PlayerFeature] init completed in ${sw.elapsedMilliseconds}ms',
    );
    // 启动时序收尾 — playerInit 打点后输出整条 Timeline 日志（幂等）。
    widget.startupTimeline.mark(StartupTimeline.phasePlayerInit);
    widget.startupTimeline.ready();
    if (mounted) setState(() => _ready = true);
  }

  /// 打开媒体文件选择器，或在选择器已显示时请求其获得 attention。
  ///
  /// 选择、路径过滤与顺序播放由 [FilePickerCoordinator] 统一处理，确保按钮和
  /// 快捷键触发同一单开会话语义。
  Future<void> _openFile() => _filePickerCoordinator.open();

  /// 处理文件拖放事件 (v0.0.5 队列语义).
  ///
  /// 单文件 → [PlaybackController.openAndPlay] (自动装载同目录队列);
  /// 多文件 → 按拖入顺序整体装载队列并从第一个起播。路径安全校验统一
  /// 由引擎装载前各层执行 (多文件路径交引擎镜像, 单文件走 controller 安检)。
  void _onFilesDropped(List<String> paths) {
    if (paths.isEmpty) return;
    if (paths.length == 1) {
      unawaited(_services.controller.openAndPlay(paths.first));
      return;
    }
    unawaited(_openDroppedQueue(paths));
  }

  /// 多文件拖入 → 整体装载队列 (替换语义), 从第一个起播.
  Future<void> _openDroppedQueue(List<String> paths) async {
    final engine = _services.engine;
    final result = await engine.openPlaylist(paths, startIndex: 0);
    switch (result) {
      case OpenSuccess():
        engine.play();
      case OpenError(:final error):
        _services.controller.onError?.call(error);
      case OpenSuperseded():
        break;
    }
  }

  @override
  void dispose() {
    _filePickerCoordinator.dispose();
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

  /// 构建播放器主界面，将单文件播放服务注入 [PlayerScreen]。
  Widget _buildPlayerScreen() {
    final engine = _services.engine;

    return PlayerScreen(
      engine: engine,
      mediaKitController: _services.mediaKitVideoController,
      controller: _services.controller,
      playlistCoordinator: _services.playlistCoordinator,
      customBindings: _customBindings,
      windowService: _services.windowService,
      onOpenFile: () => unawaited(_openFile()),
      onFilesDropped: _onFilesDropped,
      onDragHoverChanged: (hovering) {
        setState(() => _isDragHovering = hovering);
      },
      emptyState: EmptyState(
        onOpenFile: () => unawaited(_openFile()),
        isDragHovering: _isDragHovering,
        engineState: engine.state,
      ),
    );
  }
}
