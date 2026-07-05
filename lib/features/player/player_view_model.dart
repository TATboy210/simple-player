/// 模块级概览：播放器 ViewModel — MVVM 架构的 ViewModel 层
///
/// 本文件是 MVVM 模式中的 ViewModel 层，从 PlayerFeature 中提取的
/// 纯业务逻辑和 UI 状态，不依赖 BuildContext 和 Widget 树。
///
/// 核心设计原则：
/// 1. ChangeNotifier 模式 — 状态变更通过 notifyListeners() 通知 UI 重建
/// 2. 不涉及 BuildContext — 业务逻辑可独立于 Widget 树进行单元测试
/// 3. 通过 PlayerServices 持有所有播放服务的引用
/// 4. 使用工厂方法 create() 异步创建，避免构造函数中的异步操作
///
/// 与 PlayerFeature 的关系：
/// - PlayerViewModel 提供业务逻辑方法（init/openFile/onFilesDropped 等）
/// - PlayerFeature（或未来的 PlayerView）通过 ChangeNotifier 监听状态变化
/// - 当前两者并存（历史遗留），后续重构目标是让 PlayerFeature 委托给 ViewModel
///
/// 架构位置：App → PlayerFeature → **PlayerViewModel** → PlayerServices
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/startup/startup_coordinator.dart';
import '../../kernel/utils/log.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/shared/osd_overlay.dart';
import '../../ui/shared/play_mode_utils.dart';
import 'player_services.dart';

/// 播放器 ViewModel — 业务逻辑与 UI 状态的纯 Dart 类
///
/// 作为 MVVM 的 ViewModel 层，[PlayerViewModel] 负责：
/// - 持有 [PlayerServices] 实例并管理其生命周期
/// - 管理 UI 级状态：初始化就绪、错误信息、拖拽悬停、自定义快捷键
/// - 提供文件选择、拖放、播放模式切换等业务逻辑方法
///
/// 不涉及 BuildContext，不涉及 Widget 构建 — 可独立于 UI 树进行单元测试。
/// 状态变更通过 [notifyListeners()] 通知 UI 层重建。
class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({
    required this.coordinator,
    required this.windowService,
    this.engineOverride,
  });

  /// 启动协调器，用于上报初始化各阶段进度
  final StartupCoordinator coordinator;

  /// Win32 窗口桥接服务，用于全屏/窗口控制等原生操作
  final WindowBridge windowService;

  /// 可选的引擎覆盖实例（调试模式下注入 MockEngine 替代 FvpEngine）
  final EngineState? engineOverride;

  /// 服务容器实例（init() 成功后才可访问）
  PlayerServices? _services;
  PlayerServices get services => _services!;

  /// 初始化是否完成（控制 UI 渲染状态）
  bool _ready = false;
  bool get ready => _ready;

  /// 初始化是否出错（显示错误状态 UI）
  bool _error = false;
  bool get hasError => _error;

  /// 错误信息文本（显示在错误状态 UI 中）
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  /// 是否处于文件拖拽悬停状态（控制拖拽提示 UI 显示）
  bool _isDragHovering = false;
  bool get isDragHovering => _isDragHovering;

  /// 从 SettingsStore 加载的自定义快捷键绑定（key: 快捷键名称, value: 按键组合）
  Map<String, String> _customBindings = {};
  Map<String, String> get customBindings => _customBindings;

  /// 允许的文件扩展名 — 视频格式 + 音频格式
  ///
  /// 使用 static const 确保编译期常量，避免每次调用 FilePicker 时重新创建列表。
  /// 与 PlayerFeature._openFile() 中的列表保持一致（后续应统一到此常量）。
  static const allowedExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    'm4v', 'ts', 'rmvb', 'mpg', 'mpeg', '3gp', 'ogv', 'vob',
    'mp3', 'flac', 'wav', 'aac', 'ogg', 'opus', 'm4a',
    'wma', 'ape', 'alac', 'aiff',
  ];

  /// 初始化播放器服务
  ///
  /// 使用 [PlayerServices.create()] 工厂方法异步创建服务容器，
  /// 内部会创建引擎、播放列表、控制器、视频处理服务等。
  /// 初始化完成后从 SettingsStore 加载自定义快捷键绑定。
  ///
  /// 错误处理：捕获所有异常，设置 _error 状态并通知 UI，不会向上传播。
  Future<void> init() async {
    final sw = Stopwatch()..start();
    coordinator.report(StartupPhase.playerInit, 0.0, 'Initializing engine...');
    try {
      _services = await PlayerServices.create(
        windowService: windowService,
        engineOverride: engineOverride,
      );
      coordinator.report(StartupPhase.playerInit, 0.7, 'Loading settings...');
      _customBindings = await SettingsStore.loadShortcuts();
    } catch (e, stackTrace) {
      log.e('[PlayerViewModel] init failed: $e', error: e, stackTrace: stackTrace);
      _error = true;
      _errorMessage = '$e';
      notifyListeners();
      return;
    }
    log.d('[PlayerViewModel] init completed in ${sw.elapsedMilliseconds}ms');
    coordinator.markReady();
    _ready = true;
    notifyListeners();
  }

  /// 打开文件选择器并播放选中的文件
  ///
  /// 使用 FilePicker 以 custom 模式打开系统文件选择器，
  /// 限制为 [allowedExtensions] 中定义的视频/音频格式。
  /// 选中的文件逐个通过 PlaybackController.openAndPlay() 打开播放。
  Future<void> openFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          await _services!.controller.openAndPlay(file.path!);
        }
      }
    }
  }

  /// 处理文件拖放事件 — 将拖入的文件路径添加到播放列表
  void onFilesDropped(List<String> paths) {
    _services!.controller.addFiles(paths);
  }

  /// 切换播放模式（循环全部 → 单曲循环 → 随机）并通过 OSD 显示当前模式
  ///
  /// 接收 [AppLocalizations] 参数用于生成本地化标签，
  /// 因为 ViewModel 不持有 BuildContext，无法直接访问 AppLocalizations。
  void onTogglePlayMode(AppLocalizations l10n) {
    _services!.controller.togglePlayMode();
    OsdService.I.show(
      playModeLabel(_services!.playlist.mode, l10n),
      icon: playModeIcon(_services!.playlist.mode),
    );
  }

  /// 设置文件拖拽悬停状态并通知 UI 更新
  void setDragHovering(bool v) {
    _isDragHovering = v;
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }
}
