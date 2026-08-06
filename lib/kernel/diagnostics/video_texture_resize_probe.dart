/// 拖窗期间 VideoController 纹理重建诊断 — 并联 [ResizeFrameMetrics].
///
/// 监听与 [ResizeFrameMetrics] 同一个 `isResizing` 信号 (边沿开/关会话),
/// 会话内计数 `VideoController.rect` / `textureId` 的变化次数与时间点,
/// 会话结束输出摘要. 用于区分拖窗延迟的两个互斥根因 (源码调查见
/// media_kit_video 2.0.1 `video_texture.dart` + `native_video_controller/real.dart`):
///
/// - 根因甲 (native 纹理重建): rect/id 在会话内频繁变化 → C++ 侧 D3D11
///   render target 重建, 每次重建有固有开销 + 重建期间旧纹理被 FittedBox
///   拉伸 → "悬浮画面适应窗口"延迟感. 对应 player_screen.dart:437 注释.
/// - 根因乙 (纯合成缩放): rect/id 在会话内零变化 → FittedBox 把固定纹理
///   GPU 缩放到新窗口, 延迟感来自缩放滤波/合成帧调度, 非纹理重建.
///
/// 判定: rectChanges=0 且 idChanges=0 → 乙; 否则 → 甲 (次数越多重建越频繁).
/// rect 尺寸轨迹揭示 rect 是否跟随窗口尺寸 (甲的标志) 或恒定 (乙的标志).
///
/// 仅 debug 模式生效: [kDebugMode] 门控, release 零开销.
/// 生命周期跟随 PlayerScreen, 由其构造/dispose.
library;

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;

import 'kernel_logger.dart';

/// 拖窗纹理重建探针 — 会话式, 并联 [ResizeFrameMetrics].
///
/// Binds to [isResizing] + [rect] + [textureId] listenables; counts
/// native-driven rect/textureId changes during resize sessions to
/// distinguish texture-rebuild jank (root cause A) from pure-compositing
/// jank (root cause B).
final class VideoTextureResizeProbe {
  /// 构造 — 绑定 isResizing (会话边沿) + rect/textureId (被观测信号).
  ///
  /// [isResizing] resize 状态信号 (与 ResizeFrameMetrics 同源).
  /// [rect] `VideoController.rect` — native 推送的渲染 Rect.
  /// [textureId] `VideoController.id` — native 推送的 texture id.
  /// [logger] 可选日志门面; 省略时走 [KernelLogger.I].
  VideoTextureResizeProbe({
    required ValueListenable<bool> isResizing,
    required ValueListenable<Rect?> rect,
    required ValueListenable<int?> textureId,
    KernelLogger? logger,
  })  : _isResizing = isResizing,
        _rect = rect,
        _textureId = textureId,
        _logger = logger,
        _enabled = kDebugMode {
    // release 构造不注册 listener — 零稳态开销, listener 也被 tree-shake.
    if (_enabled) {
      _isResizing.addListener(_onResizingChanged);
    }
  }

  final ValueListenable<bool> _isResizing;
  final ValueListenable<Rect?> _rect;
  final ValueListenable<int?> _textureId;
  final KernelLogger? _logger;
  final bool _enabled;

  bool _sessionActive = false;
  bool _disposed = false;

  /// 会话开始时的墙钟基准 (会话内事件时间戳相对此值).
  DateTime? _sessionStart;

  /// rect 变化事件 — (相对会话开始的毫秒, 新 rect 尺寸 "WxH").
  final List<({int ms, String size})> _rectEvents = [];

  /// textureId 变化次数 (id 变化即 native 丢弃旧纹理重建, 计数即可).
  int _idChanges = 0;

  /// 会话开始时的 rect/id 快照 — 用于输出尺寸轨迹起点.
  Rect? _rectAtStart;
  int? _idAtStart;

  /// trail 截断阈值 — 超过则首尾采样, 避免拖窗长会话日志爆炸.
  static const _trailHead = 8;
  static const _trailTail = 4;

  /// isResizing 变化 — 边沿触发会话开/关 (与 ResizeFrameMetrics 同逻辑).
  void _onResizingChanged() {
    if (_disposed || !_enabled) return;
    final resizing = _isResizing.value;
    if (resizing) {
      if (!_sessionActive) _startSession();
    } else {
      if (_sessionActive) _endSession();
    }
  }

  /// 开启会话 — 记基准时间 + 起点快照, 注册 rect/id listener.
  void _startSession() {
    _sessionActive = true;
    _sessionStart = DateTime.now();
    _rectEvents.clear();
    _idChanges = 0;
    _rectAtStart = _rect.value;
    _idAtStart = _textureId.value;
    _rect.addListener(_onRectChanged);
    _textureId.addListener(_onIdChanged);
  }

  /// rect 变化 — 记录相对会话开始的毫秒 + 新尺寸 (width/height 取整).
  void _onRectChanged() {
    if (_disposed || !_sessionActive) return;
    final r = _rect.value;
    // local 捕获 _sessionStart 消除字段 `!` (字段不提升).
    final start = _sessionStart;
    final ms = start == null
        ? 0
        : DateTime.now().difference(start).inMilliseconds;
    final size = r == null
        ? 'null'
        : '${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}';
    _rectEvents.add((ms: ms, size: size));
  }

  /// textureId 变化 — 计数 (id 每次 native 重建递增).
  void _onIdChanged() {
    if (_disposed || !_sessionActive) return;
    _idChanges++;
  }

  /// 结束会话 — 移除 listener, 输出摘要, 清空.
  void _endSession() {
    _rect.removeListener(_onRectChanged);
    _textureId.removeListener(_onIdChanged);
    _sessionActive = false;
    _logSummary();
    _rectEvents.clear();
    _sessionStart = null;
  }

  /// 输出会话摘要 — rect/id 变化计数 + rect 尺寸轨迹 + 根因判定.
  void _logSummary() {
    final logger = _logger ?? KernelLogger.I;
    final rectCount = _rectEvents.length;
    final idCount = _idChanges;

    // 根因判定: rect/id 零变化 → 乙 (纯合成缩放); 否则 → 甲 (纹理重建).
    final verdict = (rectCount == 0 && idCount == 0)
        ? '根因乙: 纯合成缩放 (native 未重建纹理)'
        : '根因甲: native 纹理重建';

    // local 捕获 _rectAtStart 消除字段 `!` (字段不提升).
    final start = _rectAtStart;
    final startSize = start == null
        ? 'null'
        : '${start.width.toStringAsFixed(0)}x${start.height.toStringAsFixed(0)}';

    logger.info(
      '[VideoTextureResizeProbe] session: rectChanges=$rectCount idChanges=$idCount | '
      'rect $startSize → ${_formatTrail()} | '
      'idAtStart=$_idAtStart → +$idCount changes | '
      '$verdict',
    );
  }

  /// 格式化 rect 尺寸轨迹 — 短序列全显, 长序列首尾采样.
  ///
  /// 每个事件格式为 `+<ms>ms <WxH>`, 用 ` → ` 连接.
  String _formatTrail() {
    if (_rectEvents.isEmpty) return '(无变化)';
    if (_rectEvents.length <= _trailHead + _trailTail) {
      return _rectEvents.map((e) => '+${e.ms}ms ${e.size}').join(' → ');
    }
    final head = _rectEvents
        .take(_trailHead)
        .map((e) => '+${e.ms}ms ${e.size}');
    final tail = _rectEvents
        .skip(_rectEvents.length - _trailTail)
        .map((e) => '+${e.ms}ms ${e.size}');
    final omitted = _rectEvents.length - _trailHead - _trailTail;
    return '${head.join(' → ')} → …(省略 $omitted)… → ${tail.join(' → ')}';
  }

  /// 释放 — 移除 listener. 幂等. 必须在所监听 ValueListenable dispose 前调.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_enabled) {
      // 会话进行中才需移除 rect/id listener (否则未注册, removeListener 会抛).
      if (_sessionActive) {
        _rect.removeListener(_onRectChanged);
        _textureId.removeListener(_onIdChanged);
      }
      _isResizing.removeListener(_onResizingChanged);
    }
    _sessionActive = false;
    _rectEvents.clear();
  }
}
