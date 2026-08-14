/// 左侧按钮组模块 — 音量 + 倍速
///
/// 从 ControlBar 中提取的独立 Widget，负责控制栏底部行左侧按钮群。
/// 单文件播放器仅保留音量控制与倍速选择。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'speed_button.dart';
import 'volume_controls.dart';

/// 左侧按钮组：音量 + 倍速。
///
/// 数据源从 [MediaEngine] 解耦为 volume/isMuted/rate listenable 与对应回调，
/// 由 [VolumeButton]、[VolumeSlider] 和 [SpeedButton] 分别消费。
class LeftButtonGroup extends StatelessWidget {
  final ValueListenable<double> volume;
  final ValueListenable<bool> isMuted;
  final ValueListenable<double> rate;
  final VoidCallback onToggleMute;
  final void Function(double) onSetVolume;
  final void Function(double) onSetRate;
  final bool showSecondaryActions;

  /// 子控件交互边界透传给 Overlay，统一冻结或恢复自动隐藏策略。
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const LeftButtonGroup({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.rate,
    required this.onToggleMute,
    required this.onSetVolume,
    required this.onSetRate,
    this.showSecondaryActions = true,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VolumeButton(
          volume: volume,
          isMuted: isMuted,
          onToggleMute: onToggleMute,
          onSetVolume: onSetVolume,
        ),
        if (showSecondaryActions)
          VolumeSlider(
            volume: volume,
            onSetVolume: onSetVolume,
            onInteractionStart: onInteractionStart,
            onInteractionEnd: onInteractionEnd,
          ),
        if (showSecondaryActions) const SizedBox(width: Tokens.spXs),
        if (showSecondaryActions) SpeedButton(rate: rate, onSetRate: onSetRate),
      ],
    );
  }
}
