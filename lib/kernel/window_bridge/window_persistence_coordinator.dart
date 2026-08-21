import 'dart:async';
import 'dart:ui';

import '../persistence/window_persistence.dart';
import 'window_bridge.dart';
import 'window_service_state.dart';

/// 串行保存窗口快照，隔离平台读取和持久化异常。
final class WindowPersistenceCoordinator {
  WindowPersistenceCoordinator({
    required WindowServiceState state,
    required WindowPersistence persistence,
    required Future<Offset> Function() readPosition,
    required void Function(String message, Object error, StackTrace stackTrace)
    log,
  }) : _state = state,
       _persistence = persistence,
       _readPosition = readPosition,
       _log = log;

  final WindowServiceState _state;
  final WindowPersistence _persistence;
  final Future<Offset> Function() _readPosition;
  final void Function(String, Object, StackTrace) _log;
  Future<void> _operation = Future<void>.value();

  /// 保存当前窗口几何；全屏时跳过，避免保存 media_kit route 尺寸。
  Future<void> save({Size? size}) {
    final operation = _operation.then((_) => _saveSerialized(size: size));
    _operation = operation.catchError((Object error, StackTrace stackTrace) {
      _log('[WindowPersistenceCoordinator.save]', error, stackTrace);
    });
    return operation;
  }

  Future<void> _saveSerialized({Size? size}) async {
    if (_state.disposed || _state.mode.value.isFullscreen) return;
    try {
      final position = await _readPosition();
      if (_state.disposed) return;
      await _persistence.save(
        PersistedWindowState(
          size: size ?? _state.windowSize.value,
          position: position,
          alwaysOnTop: _state.isAlwaysOnTop.value,
          isMaximized: _state.mode.value == WindowMode.maximized,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log('[WindowPersistenceCoordinator._saveSerialized]', error, stackTrace);
    }
  }
}
