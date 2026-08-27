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
/// 架构位置：App → DeferredPlayerFeature → **PlayerFeature** → PlayerScreen
/// 依赖链：PlayerFeature → PlayerServices → PlaybackController → MediaKitEngine
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../kernel/window_bridge/window_manager_service.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../kernel/player_services.dart';
import '../../kernel/startup/startup_coordinator.dart';
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
  /// 启动协调器，用于上报初始化各阶段进度
  final StartupCoordinator coordinator;

  /// Win32 窗口桥接服务，用于全屏/窗口控制等原生操作
  final WindowBridge windowService;

  const PlayerFeature({
    super.key,
    required this.coordinator,
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
  /// 1. 上报 StartupPhase.playerInit 开始（进度 0.0）
  /// 2. 调用 PlayerServices.init() — 初始化引擎、控制器与视频处理服务
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
        'Applying built-in defaults...',
      );
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
    widget.coordinator.markReady();
    if (mounted) setState(() => _ready = true);
  }

  /// 打开媒体文件选择器，或在选择器已显示时请求其获得 attention。
  ///
  /// 选择、路径过滤与顺序播放由 [FilePickerCoordinator] 统一处理，确保按钮和
  /// 快捷键触发同一单开会话语义。
  Future<void> _openFile() => _filePickerCoordinator.open();

  /// 处理文件拖放事件，仅打开第一个路径。
  ///
  /// 拖放边界可能一次提供多个文件，但 v1.8 不再隐式建立播放队列；实际路径
  /// 安全与媒体类型校验继续统一由 [PlaybackController.openAndPlay] 执行。
  void _onFilesDropped(List<String> paths) {
    if (paths.isEmpty) return;
    unawaited(_services.controller.openAndPlay(paths.first));
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
