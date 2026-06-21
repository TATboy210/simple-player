import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/events/player_events.dart';
import '../../core/state/playback_state.dart';
import '../../infra/event_bus/event_bus.dart';
import '../widgets/osd_overlay.dart';
import '../widgets/title_bar.dart';
import 'auto_hide_controller.dart';
import 'control_bar.dart';

/// 控件叠加层 — 统一管理鼠标显隐 + TitleBar + OSD + ControlBar
///
/// MouseRegion 监听 hover，触发 AutoHideController 的 show/hide 状态机。
/// 用 ValueListenableBuilder 监听 opacity，实现淡入淡出。
/// IgnorePointer 在隐藏时让鼠标事件穿透到下层视频。
class ControlsOverlay extends StatefulWidget {
  final EventBus bus;
  final bool isFullscreen;

  const ControlsOverlay({
    super.key,
    required this.bus,
    required this.isFullscreen,
  });

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay>
    with SingleTickerProviderStateMixin {
  late final AutoHideController _autoHide;
  final _subs = <StreamSubscription>[];

  PlaybackState _state = PlaybackState.idle;
  int _positionMs = 0;
  int _durationMs = 0;
  double _volume = 100;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _autoHide = AutoHideController(
      vsync: this,
      bus: widget.bus,
      isFullscreen: widget.isFullscreen,
    );

    _subs.add(
      widget.bus.on<StateChanged>().listen((e) {
        if (mounted) setState(() => _state = e.state);
      }),
    );
    _subs.add(
      widget.bus.on<PositionChanged>().listen((e) {
        if (mounted) {
          setState(() {
            _positionMs = e.positionMs;
            _durationMs = e.durationMs;
          });
        }
      }),
    );
    _subs.add(
      widget.bus.on<VolumeChanged>().listen((e) {
        if (mounted) setState(() => _volume = e.volume);
      }),
    );
    _subs.add(
      widget.bus.on<MuteChanged>().listen((e) {
        if (mounted) setState(() => _isMuted = e.muted);
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _autoHide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _autoHide.visible,
      builder: (context, isVisible, _) {
        return MouseRegion(
          cursor: isVisible
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) => _autoHide.onMouseMove(),
          onEnter: (_) => _autoHide.onMouseMove(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _autoHide.onMouseMove(),
            onDoubleTap: () =>
                widget.bus.fire(const TogglePlayPauseCommand()),
            child: FadeTransition(
              opacity: _autoHide.opacity,
              child: IgnorePointer(
                ignoring: !isVisible,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: TitleBar(bus: widget.bus),
                    ),
                    const Positioned.fill(
                      child: OsdOverlay(),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ControlBar(
                        bus: widget.bus,
                        state: _state,
                        positionMs: _positionMs,
                        durationMs: _durationMs,
                        volume: _volume,
                        isMuted: _isMuted,
                        isFullscreen: widget.isFullscreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
