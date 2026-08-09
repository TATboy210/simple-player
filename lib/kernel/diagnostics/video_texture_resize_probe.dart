/// 拖窗期间 VideoController 纹理信号诊断，并联 [ResizeFrameMetrics]。
///
/// 探针在 Debug/Profile 模式观察 `rect` 与 `textureId`，输出固定结构的会话
/// 摘要。分类只陈述 Dart 侧可见信号，不据此推断 native 合成或纹理重建成本。
library;

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show ValueListenable, kReleaseMode;

import 'kernel_logger.dart';

/// 会话式视频纹理 resize 探针。
///
/// 默认在 Debug/Profile 启用、Release 禁用；测试可通过 [enabled] 和
/// [monotonicNow] 注入确定性策略。任一 controller observer 缺失时，仍输出
/// 会话摘要，但以 `probeUnavailable` 明确标记，避免误判为零 Dart 信号变化。
final class VideoTextureResizeProbe {
  /// 创建探针，并同步接管构造时已经开始的 resize 会话。
  VideoTextureResizeProbe({
    required ValueListenable<bool> isResizing,
    required ValueListenable<int> resizeSessionId,
    ValueListenable<Rect?>? rect,
    ValueListenable<int?>? textureId,
    KernelLogger? logger,
    Duration Function()? monotonicNow,
    bool enabled = !kReleaseMode,
  }) : _isResizing = isResizing,
       _resizeSessionId = resizeSessionId,
       _rect = rect,
       _textureId = textureId,
       _logger = logger,
       _enabled = enabled,
       _stopwatch = monotonicNow == null ? (Stopwatch()..start()) : null,
       _monotonicNow = monotonicNow {
    if (_enabled) {
      _isResizing.addListener(_onResizingChanged);
      _onResizingChanged();
    }
  }

  /// 结构化日志固定字段；修改字段时测试会显式提示 schema 变化。
  static const Set<String> contextKeys = {
    'schemaVersion',
    'sessionId',
    'sessionKind',
    'probeUnavailable',
    'classification',
    'durationUs',
    'rectChanges',
    'textureIdChanges',
    'rectAtStart',
    'rectAtEnd',
    'textureIdAtStart',
    'textureIdAtEnd',
    'rectTrail',
    'rectTrailOmitted',
    'textureIdTrail',
    'textureIdTrailOmitted',
  };

  static const int _trailHead = 8;
  static const int _trailTail = 4;
  static const int _trailLimit = _trailHead + _trailTail;

  final ValueListenable<bool> _isResizing;
  final ValueListenable<int> _resizeSessionId;
  final ValueListenable<Rect?>? _rect;
  final ValueListenable<int?>? _textureId;
  final KernelLogger? _logger;
  final bool _enabled;
  final Stopwatch? _stopwatch;
  final Duration Function()? _monotonicNow;
  final List<Map<String, Object?>> _rectTrail = [];
  final List<Map<String, Object?>> _textureIdTrail = [];

  bool _sessionActive = false;
  bool _disposed = false;
  int _sessionId = 0;
  Duration _sessionStart = Duration.zero;
  Rect? _rectAtStart;
  int? _textureIdAtStart;
  Rect? _previousRect;
  int? _previousTextureId;
  int _rectChanges = 0;
  int _textureIdChanges = 0;
  int _rectTrailOmitted = 0;
  int _textureIdTrailOmitted = 0;

  /// 同时持有两个 controller 信号时，探针才能形成可解释的分类。
  bool get _isProbeAvailable => _rect != null && _textureId != null;

  Duration _now() =>
      _monotonicNow?.call() ?? _stopwatch?.elapsed ?? Duration.zero;

  void _onResizingChanged() {
    if (_disposed || !_enabled) return;
    if (_isResizing.value) {
      if (!_sessionActive) _startSession();
      return;
    }
    if (_sessionActive) _endSession();
  }

  void _startSession() {
    _resetSessionState();
    // 上升沿冻结关联 ID，避免下一会话开始后污染本会话的摘要归属。
    _sessionId = _resizeSessionId.value;
    _sessionStart = _now();
    _sessionActive = true;

    if (!_isProbeAvailable) return;
    final rect = _rect;
    final textureId = _textureId;
    if (rect == null || textureId == null) return;

    _rectAtStart = rect.value;
    _textureIdAtStart = textureId.value;
    _previousRect = _rectAtStart;
    _previousTextureId = _textureIdAtStart;
    rect.addListener(_onRectChanged);
    textureId.addListener(_onTextureIdChanged);
  }

  void _onRectChanged() {
    final rect = _rect;
    if (_disposed || !_sessionActive || rect == null) return;

    final next = rect.value;
    if (next == _previousRect) return;
    _previousRect = next;
    _rectChanges++;
    _appendBounded(_rectTrail, {
      'elapsedUs': _elapsedUs(),
      'rect': _rectToContext(next),
    }, onOmitted: () => _rectTrailOmitted++);
  }

  void _onTextureIdChanged() {
    final textureId = _textureId;
    if (_disposed || !_sessionActive || textureId == null) return;

    final next = textureId.value;
    final previous = _previousTextureId;
    if (next == previous) return;
    _previousTextureId = next;
    _textureIdChanges++;
    _appendBounded(_textureIdTrail, {
      'elapsedUs': _elapsedUs(),
      'previousId': previous,
      'nextId': next,
    }, onOmitted: () => _textureIdTrailOmitted++);
  }

  int _elapsedUs() => (_now() - _sessionStart).inMicroseconds;

  void _appendBounded(
    List<Map<String, Object?>> trail,
    Map<String, Object?> event, {
    required void Function() onOmitted,
  }) {
    if (trail.length == _trailLimit) {
      // 始终保留最早八项和最新四项，避免长会话无限放大日志。
      trail.removeAt(_trailHead);
      onOmitted();
    }
    trail.add(event);
  }

  void _endSession() {
    final probeUnavailable = !_isProbeAvailable;
    final rect = _rect;
    final textureId = _textureId;
    if (!probeUnavailable) {
      rect?.removeListener(_onRectChanged);
      textureId?.removeListener(_onTextureIdChanged);
    }

    _sessionActive = false;
    final context = <String, Object?>{
      'schemaVersion': 1,
      'sessionId': _sessionId,
      'sessionKind': 'drag+settle',
      'probeUnavailable': probeUnavailable,
      'classification': probeUnavailable ? null : _classification(),
      'durationUs': _elapsedUs(),
      'rectChanges': _rectChanges,
      'textureIdChanges': _textureIdChanges,
      'rectAtStart': _rectToContext(_rectAtStart),
      'rectAtEnd': probeUnavailable ? null : _rectToContext(rect?.value),
      'textureIdAtStart': _textureIdAtStart,
      'textureIdAtEnd': probeUnavailable ? null : textureId?.value,
      'rectTrail': List<Map<String, Object?>>.unmodifiable(_rectTrail),
      'rectTrailOmitted': _rectTrailOmitted,
      'textureIdTrail': List<Map<String, Object?>>.unmodifiable(
        _textureIdTrail,
      ),
      'textureIdTrailOmitted': _textureIdTrailOmitted,
    };

    // 先关闭会话并清除旧采样，再调用可重入的外部 logger。否则日志 sink 若同步
    // 开启下一次 resize，当前收尾返回后会错误清空新会话的快照与计数。
    _resetSessionState();
    (_logger ?? KernelLogger.I).info(
      'video_texture_resize_probe',
      context: context,
    );
  }

  String _classification() {
    if (_textureIdChanges > 0) return 'texture-id-changed';
    if (_rectChanges > 0) return 'rect-only-changed';
    return 'no-dart-signal-change';
  }

  Map<String, Object?>? _rectToContext(Rect? rect) => rect == null
      ? null
      : {
          'left': rect.left,
          'top': rect.top,
          'right': rect.right,
          'bottom': rect.bottom,
          'width': rect.width,
          'height': rect.height,
        };

  void _resetSessionState() {
    _rectTrail.clear();
    _textureIdTrail.clear();
    _rectChanges = 0;
    _textureIdChanges = 0;
    _rectTrailOmitted = 0;
    _textureIdTrailOmitted = 0;
    _rectAtStart = null;
    _textureIdAtStart = null;
    _previousRect = null;
    _previousTextureId = null;
  }

  /// 移除所有 listener 并丢弃未结束的会话；重复调用安全。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_enabled) {
      if (_sessionActive && _isProbeAvailable) {
        _rect?.removeListener(_onRectChanged);
        _textureId?.removeListener(_onTextureIdChanged);
      }
      _isResizing.removeListener(_onResizingChanged);
    }
    _sessionActive = false;
    _stopwatch?.stop();
    _resetSessionState();
  }
}
