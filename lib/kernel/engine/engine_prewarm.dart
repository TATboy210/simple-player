import 'package:fvp/mdk.dart' as mdk;

import '../utils/log.dart';

/// 引擎预热 — 在应用启动时提前初始化 MDK/FFmpeg 渲染上下文
///
/// 调用 [prewarm] 会创建一个临时 mdk.Player 并立即销毁，
/// 触发 FFmpeg codec 注册和 D3D11 渲染上下文初始化。
/// 后续 FvpEngine 构造时可跳过冷启动开销。
class EnginePrewarm {
  EnginePrewarm._();

  static bool _prewarmed = false;

  /// 是否已预热
  static bool get isPrewarmed => _prewarmed;

  /// 预热 MDK 渲染上下文
  ///
  /// 安全调用：任何异常都会被捕获，不影响后续播放。
  /// 幂等：多次调用仅生效一次。
  static Future<void> prewarm() async {
    if (_prewarmed) return;
    _prewarmed = true;
    try {
      final player = mdk.Player();
      player.dispose();
    } on Object catch (e) {
      // 预热失败不影响后续播放，仅标记未完成
      _prewarmed = false;
      log.d('EnginePrewarm failed: $e');
    }
  }
}
