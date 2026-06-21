import 'dart:async';

import '../../infra/window/window_service.dart';
import '../../infra/event_bus/event_bus.dart';
import '../../core/events/window_events.dart';

/// 窗口功能模块 — 订阅命令，调用 WindowService
///
/// 不直接暴露给 UI。UI 通过 EventBus.fire(Command) 发送命令。
/// 状态通过 EventBus.on<Event>() 回传。
class WindowFeature {
  final WindowService _service;
  final EventBus _bus;

  WindowFeature(this._service, this._bus);

  StreamSubscription<WindowCommand>? _sub;

  /// 初始化 — 订阅窗口命令事件
  void init() {
    _sub = _bus.on<WindowCommand>().listen(_handleCommand);
  }

  void _handleCommand(WindowCommand cmd) {
    switch (cmd) {
      case ToggleFullscreenCommand():
        _service.setFullscreen(!_service.isFullscreen);
      case SetFullscreenCommand(:final value):
        _service.setFullscreen(value);
      case ToggleMaximizeCommand():
        if (_service.isMaximized) {
          _service.restore();
        } else {
          _service.maximize();
        }
      case SetAlwaysOnTopCommand(:final value):
        _service.setAlwaysOnTop(value);
      case MinimizeCommand():
        _service.minimize();
      case RestoreCommand():
        _service.restore();
      case CloseCommand():
        _service.close();
      case StartDraggingCommand():
        _service.startDragging();
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
