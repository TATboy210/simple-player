import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../shared/value_listenable_builder2.dart';
import '../shared/osd_overlay.dart';

/// 音量按钮（单击静音）
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [volume]/[isMuted]
/// ValueListenable + [onToggleMute]/[onSetVolume] 回调。mute/unmute 仍
/// 通过 onToggleMute(=setMute(!isMuted)) + onSetVolume 协同,保 _savedVolume
/// 语义等价。mute 分支反序(onToggleMute 先 + onSetVolume(0) 后):
/// 避免 FakeEngine.setVolume(0) 联动 isMuted=true 后 onToggleMute 翻回 false
/// (生产 MediaKitEngine.setVolume 不联动 isMuted,两种 engine 下都正确)。
class VolumeButton extends StatefulWidget {
  final ValueListenable<double> volume;
  final ValueListenable<bool> isMuted;
  final VoidCallback onToggleMute;
  final void Function(double) onSetVolume;

  const VolumeButton({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onToggleMute,
    required this.onSetVolume,
  });

  @override
  State<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<VolumeButton> {
  double _savedVolume = 1.0;

  @override
  void initState() {
    super.initState();
    widget.volume.addListener(_onVolumeChanged);
  }

  @override
  void didUpdateWidget(covariant VolumeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      oldWidget.volume.removeListener(_onVolumeChanged);
      widget.volume.addListener(_onVolumeChanged);
    }
  }

  @override
  void dispose() {
    widget.volume.removeListener(_onVolumeChanged);
    super.dispose();
  }

  /// 同步 _savedVolume：用户拖滑块时自动跟踪，并在静音状态下自动取消静音
  void _onVolumeChanged() {
    final v = widget.volume.value;
    if (v > 0) {
      _savedVolume = v;
      // 静音状态下拖滑块到非零值 → 自动取消静音
      // onToggleMute = setMute(!isMuted),此处 isMuted=true → setMute(false) 等价
      if (widget.isMuted.value) {
        widget.onToggleMute();
      }
    }
  }

  void _toggleMute() {
    final l10n = AppLocalizations.of(context);
    if (widget.isMuted.value) {
      // unmute: setMute(false) + 恢复 saved 音量
      // onToggleMute = setMute(!true) = setMute(false),等价原 engine.setMute(false)
      widget.onToggleMute();
      widget.onSetVolume(_savedVolume);
      OsdService.I.show(
        '${(_savedVolume * 100).round()}%',
        progress: _savedVolume,
      );
    } else {
      // mute: 存 saved → setMute(true) → setVolume(0)
      // 反序:onToggleMute(=setMute(!false)=setMute(true)) 必须在 onSetVolume(0)
      // 之前,避免 FakeEngine.setVolume(0) 联动 isMuted=true 后 onToggleMute
      // =setMute(!true)=setMute(false) 翻回 false。生产 MediaKitEngine.setVolume
      // 不联动 isMuted,两种 engine 下结果都是 isMuted=true + volume=0.
      _savedVolume = widget.volume.value;
      widget.onToggleMute();
      widget.onSetVolume(0);
      OsdService.I.show(l10n.mute, icon: Icons.volume_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder2<bool, double>(
      first: widget.isMuted,
      second: widget.volume,
      builder: (_, muted, volume, _) {
        IconData icon;
        if (muted || volume == 0) {
          icon = Icons.volume_off;
        } else if (volume < 0.5) {
          icon = Icons.volume_down;
        } else {
          icon = Icons.volume_up;
        }
        return GlassButton.iconOnly(
          icon: icon,
          iconSize: Tokens.iconLg,
          color: muted ? Tokens.accent : Tokens.textPrimary,
          onPressed: _toggleMute,
          tooltip: muted ? l10n.unmute : l10n.mute,
        );
      },
    );
  }
}

/// 音量滑块（内联水平条）
///
/// 拖拽期间使用 [Tokens.volumeThrottleMs] 节流引擎和 OSD 调用，
/// 松手时通过 [onChangeEnd] 立即同步最终值（零感知延迟）。
/// 鼠标滚轮保持无节流（离散事件，每秒 3-5 次）。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [volume] ValueListenable
/// + [onSetVolume] 回调。
class VolumeSlider extends StatefulWidget {
  static const _sliderTheme = SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
  );

  final ValueListenable<double> volume;
  final void Function(double) onSetVolume;

  /// 子控件交互开始时通知上层冻结自动隐藏。
  final VoidCallback? onInteractionStart;

  /// 子控件交互结束时通知上层恢复既有自动隐藏策略。
  final VoidCallback? onInteractionEnd;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onSetVolume,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  /// 节流定时器（null = 无活跃定时器）
  Timer? _throttleTimer;

  /// 节流窗口内的最新待提交音量值
  double? _pendingVolume;

  /// 拖拽中的节流处理：记录最新值，100ms 内只触发一次引擎调用
  void _onChanged(double v) {
    _pendingVolume = v;
    _throttleTimer ??= Timer(
      const Duration(milliseconds: Tokens.volumeThrottleMs),
      _flushPending,
    );
  }

  /// 定时器到期：用最新值一次性通知引擎和 OSD
  void _flushPending() {
    _throttleTimer = null;
    final v = _pendingVolume;
    if (v == null) return;
    widget.onSetVolume(v);
    OsdService.I.show('${(v * 100).round()}%', progress: v);
  }

  /// 松手时立即同步最终值（取消定时器，零延迟）
  void _onChangedEnd(double v) {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _pendingVolume = null;
    widget.onSetVolume(v);
    OsdService.I.show('${(v * 100).round()}%', progress: v);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Tokens.volumeSliderWidth,
      child: Listener(
        // 滚轮是离散事件（~3-5 次/秒），无需节流
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
            final v = (widget.volume.value + delta).clamp(0.0, 1.0);
            widget.onSetVolume(v);
            OsdService.I.show('${(v * 100).round()}%', progress: v);
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: widget.volume,
          builder: (_, volume, _) => SliderTheme(
            data: VolumeSlider._sliderTheme,
            child: Slider(
              value: volume,
              onChangeStart: (_) => widget.onInteractionStart?.call(),
              onChanged: _onChanged,
              onChangeEnd: (value) {
                _onChangedEnd(value);
                widget.onInteractionEnd?.call();
              },
              activeColor: Tokens.accent,
              inactiveColor: Tokens.bgHover,
            ),
          ),
        ),
      ),
    );
  }
}
