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

/// 播放器 ViewModel — 从 PlayerFeature 提取的业务逻辑和 UI 状态
///
/// 单一职责：
///   - 持有 PlayerServices 实例和生命周期
///   - 管理 ready/error/drag-hover/custom-bindings 等 UI 状态
///   - 提供文件选择、拖放、播放模式切换等业务逻辑
///
/// 不涉及 BuildContext，不涉及 Widget 构建。
class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({
    required this.coordinator,
    required this.windowService,
    this.engineOverride,
  });

  final StartupCoordinator coordinator;
  final WindowBridge windowService;
  final EngineState? engineOverride;

  PlayerServices? _services;
  PlayerServices get services => _services!;

  bool _ready = false;
  bool get ready => _ready;

  bool _error = false;
  bool get hasError => _error;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isDragHovering = false;
  bool get isDragHovering => _isDragHovering;

  Map<String, String> _customBindings = {};
  Map<String, String> get customBindings => _customBindings;

  /// 允许的文件扩展名
  static const allowedExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    'mp3', 'flac', 'wav', 'aac', 'ogg', 'wma', 'm4a',
  ];

  /// 初始化服务
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

  /// 打开文件选择器
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

  /// 拖放文件处理
  void onFilesDropped(List<String> paths) {
    _services!.controller.addFiles(paths);
  }

  /// 切换播放模式
  void onTogglePlayMode(AppLocalizations l10n) {
    _services!.controller.togglePlayMode();
    OsdService.I.show(
      playModeLabel(_services!.playlist.mode, l10n),
      icon: playModeIcon(_services!.playlist.mode),
    );
  }

  /// 设置拖拽悬停状态
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
