import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../utils/log.dart';

/// 引擎预热 — 在应用启动时提前初始化 MDK/FFmpeg 渲染上下文
///
/// 调用 [prewarm] 会创建一个临时 mdk.Player 并立即销毁，
/// 触发 FFmpeg codec 注册和 D3D11 渲染上下文初始化。
/// 后续 FvpEngine 构造时可跳过冷启动开销。
///
/// Tier 模型（诊断追踪，非独立初始化）：
///   - playerCreated: mdk.Player() FFI 调用完成
///   - codecsReady: FFmpeg codec 注册完成（= playerCreated，无法独立触发）
///   - gpuReady: D3D11 上下文初始化完成（= playerCreated，无法独立触发）
///   - prewarmed: player.dispose() 完成，全链路就绪
class EnginePrewarm {
  EnginePrewarm._();

  static bool _prewarmed = false;
  static bool _playerCreated = false;
  static bool _codecsReady = false;
  static bool _gpuReady = false;

  /// 是否已预热
  static bool get isPrewarmed => _prewarmed;

  /// mdk.Player() 是否已创建过（FFmpeg + D3D11 初始化完成）
  static bool get isPlayerCreated => _playerCreated;

  /// FFmpeg codec 注册是否完成
  static bool get isCodecsReady => _codecsReady;

  /// D3D11 渲染上下文是否就绪
  static bool get isGpuReady => _gpuReady;

  /// 预热 MDK 渲染上下文
  ///
  /// [onProgress] 可选回调，报告进度 (0.0 → 1.0) 和消息。
  /// 安全调用：任何异常都会被捕获，不影响后续播放。
  /// 幂等：多次调用仅生效一次。
  static Future<void> prewarm({
    void Function(double progress, String message)? onProgress,
  }) async {
    if (_prewarmed) return;
    try {
      onProgress?.call(0.0, 'Creating player...');
      final player = mdk.Player();
      _playerCreated = true;
      _codecsReady = true;
      _gpuReady = true;
      onProgress?.call(0.7, 'Disposing temp player...');

      player.dispose();
      _prewarmed = true;
      onProgress?.call(1.0, 'Prewarm complete');
    } on Exception catch (e) {
      _prewarmed = false;
      log.d('EnginePrewarm failed: $e');
    }
  }

  /// 重置全部状态标志（仅供测试使用）。
  @visibleForTesting
  static void reset() {
    _prewarmed = false;
    _playerCreated = false;
    _codecsReady = false;
    _gpuReady = false;
  }
}
