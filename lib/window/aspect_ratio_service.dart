import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../kernel/models/aspect_ratio_mode.dart';

/// 宽高比约束服务 — 通过 MethodChannel 调用原生 WM_SIZING 处理
///
/// 无视频时锁定 16:9，播放视频时匹配视频比例。
/// 设置为 0 取消约束。
class AspectRatioService {
  AspectRatioService._();
  static final AspectRatioService I = AspectRatioService._();

  static const _channel = MethodChannel('com.simple_player/aspect_ratio');

  /// 16:9（默认空闲比例）
  static const ratio16x9 = 16.0 / 9.0;

  /// 4:3
  static const ratio4x3 = 4.0 / 3.0;

  double _current = 0.0;

  /// UI 响应式通知器 — 比例变化时通知监听者
  final ratioNotifier = ValueNotifier<double>(0.0);

  double get current => _current;

  /// 设置宽高比约束（0 = 无约束）
  Future<void> setAspectRatio(double ratio) async {
    if (_current == ratio) return;
    final previous = _current; // 保存用于失败回滚
    _current = ratio;
    ratioNotifier.value = ratio;
    try {
      await _channel.invokeMethod('setAspectRatio', ratio);
    } on Exception catch (e) {
      _current = previous; // 回滚到之前的状态
      ratioNotifier.value = previous;
      debugPrint('[AspectRatio] setAspectRatio($ratio) failed: $e');
    }
  }

  /// 锁定 16:9（无视频空闲状态）
  Future<void> lock16x9() => setAspectRatio(ratio16x9);

  /// 锁定 4:3
  Future<void> lock4x3() => setAspectRatio(ratio4x3);

  /// 匹配视频宽高比（width/height 比值）
  Future<void> matchVideo(double ratio) {
    if (ratio <= 0) return Future.value();
    return setAspectRatio(ratio);
  }

  /// 取消约束
  Future<void> unlock() => setAspectRatio(0.0);

  /// 比例循环切换：16:9 → 4:3 → 21:9 → 自由 → 16:9
  static const _cycleRatios = [ratio16x9, ratio4x3, 21.0 / 9.0, 0.0];

  Future<void> cycleRatio() async {
    final idx = _cycleRatios.indexOf(_current);
    final next = _cycleRatios[(idx + 1) % _cycleRatios.length];
    await setAspectRatio(next);
  }

  /// 当前比例的显示标签（中文，UI 层通过 l10n 覆盖）
  String get currentLabel {
    if (_current == 0.0) return '自由';
    for (final mode in AspectRatioMode.values) {
      if ((_current - mode.mdkValue).abs() < 0.01) return mode.label;
    }
    return '${_current.toStringAsFixed(2)}:1';
  }
}
