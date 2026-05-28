import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/log.dart';

/// Window management service — wraps MethodChannel/EventChannel.
///
/// Provides ValueNotifier state for reactive UI binding via
/// ValueListenableBuilder. Follows the FvpEngine pattern:
/// _guardedCall for disposed-safe error handling, ValueNotifier for state.
///
/// MethodChannel: com.simple_player/window (7 commands)
/// EventChannel: com.simple_player/window_events (5 event types)
class WindowService {
  WindowService();

  static const _channel = MethodChannel('com.simple_player/window');
  static const _eventChannel =
      EventChannel('com.simple_player/window_events');

  bool _disposed = false;
  StreamSubscription<dynamic>? _eventSubscription;

  // ─── State (ValueNotifier pattern from FvpEngine) ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));

  /// Initialize event listener — call after construction.
  void init() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: (Object e) {
      log.e('WindowService event stream error', error: e);
    });
  }

  void _handleEvent(dynamic event) {
    if (_disposed) return;
    final map = event as Map;
    switch (map['event'] as String) {
      case 'onResize':
        windowSize.value = Size(
          (map['width'] as num).toDouble(),
          (map['height'] as num).toDouble(),
        );
      case 'onFullscreenChange':
        isFullscreen.value = map['fullscreen'] as bool;
      case 'onMove':
        log.d('WindowService: onMove');
      case 'onClose':
        log.d('WindowService: onClose');
      case 'onMinimize':
        log.d('WindowService: onMinimize');
    }
  }

  // ─── Commands (guardedCall pattern from FvpEngine) ───

  Future<void> _guardedCall(String name, Map<String, dynamic> args) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod(name, args);
    } on Exception catch (e) {
      log.e('WindowService.$name failed', error: e);
    }
  }

  Future<void> setFullscreen(bool value) =>
      _guardedCall('setFullscreen', {'fullscreen': value});

  Future<void> setAlwaysOnTop(bool value) =>
      _guardedCall('setAlwaysOnTop', {'alwaysOnTop': value});

  Future<void> setSize(double width, double height) =>
      _guardedCall('setSize', {'width': width, 'height': height});

  Future<void> setPosition(double x, double y) =>
      _guardedCall('setPosition', {'x': x, 'y': y});

  Future<void> setMinSize(double width, double height) =>
      _guardedCall('setMinSize', {'width': width, 'height': height});

  Future<void> setFrameless(bool value) =>
      _guardedCall('setFrameless', {'frameless': value});

  Future<Rect> getTitleBarBounds() async {
    if (_disposed) return Rect.zero;
    try {
      final result = await _channel.invokeMethod('getTitleBarBounds');
      final map = result as Map;
      return Rect.fromLTWH(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      );
    } on Exception catch (e) {
      log.e('WindowService.getTitleBarBounds failed', error: e);
      return Rect.zero;
    }
  }

  void dispose() {
    _disposed = true;
    _eventSubscription?.cancel();
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
