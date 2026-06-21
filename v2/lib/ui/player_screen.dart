import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/events/player_events.dart';
import '../infra/event_bus/event_bus.dart';
import '../infra/mpv/mpv_adapter.dart';
import '../infra/mpv/mpv_render_service.dart';
import 'player/controls_overlay.dart';
import 'widgets/video_surface.dart';

/// 播放器主屏幕 — Stack 布局：视频铺满 + 控件悬浮叠加
///
/// 架构：
///   KeyboardListener
///     Stack(fit: expand)
///       VideoSurface  ← 视频铺满整个窗口
///       ControlsOverlay ← 控件叠加（自动显隐）
///
/// 不持有 PlayerFeature 引用。
/// 命令通过 fire(PlayerCommand) 发送，
/// 状态通过 on<PlayerEvent>() 接收。
class PlayerScreen extends StatefulWidget {
  final EventBus bus;
  final MpvAdapter mpv;
  final MpvRenderService renderService;

  const PlayerScreen({
    super.key,
    required this.bus,
    required this.mpv,
    required this.renderService,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // 视频比例（仅需本地状态）
  AspectMode _aspectMode = AspectMode.auto_;
  int? _videoWidth;
  int? _videoHeight;

  final _focusNode = FocusNode();
  final _subscriptions = <StreamSubscription<PlayerEvent>>[];

  @override
  void initState() {
    super.initState();
    // 仅监听视频尺寸变化（用于 AspectMode 计算）
    // PlaybackState/Position 由 ControlsOverlay 内部订阅
    _subscriptions.add(
      widget.bus.on<TextureCreated>().listen((event) {
        setState(() {
          _videoWidth = event.width;
          _videoHeight = event.height;
        });
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) s.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _cycleAspectMode() {
    setState(() {
      _aspectMode =
          AspectMode.values[(_aspectMode.index + 1) % AspectMode.values.length];
    });
    widget.mpv.setProperty('video-aspect-override', _aspectMode.mpvAspectValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          final key = event.logicalKey;

          // A: 循环视频比例
          if (key == LogicalKeyboardKey.keyA) {
            _cycleAspectMode();
          }
          // Space: 播放/暂停
          else if (key == LogicalKeyboardKey.space) {
            widget.bus.fire(const TogglePlayPauseCommand());
          }
          // Left/Right: 快退/快进 10s
          else if (key == LogicalKeyboardKey.arrowLeft) {
            widget.bus.fire(const SkipBackwardCommand(seconds: 10));
          } else if (key == LogicalKeyboardKey.arrowRight) {
            widget.bus.fire(const SkipForwardCommand(seconds: 10));
          }
          // Up/Down: 音量 ±5%
          else if (key == LogicalKeyboardKey.arrowUp) {
            widget.bus.fire(const VolumeUpCommand());
          } else if (key == LogicalKeyboardKey.arrowDown) {
            widget.bus.fire(const VolumeDownCommand());
          }
          // M: 静音切换
          else if (key == LogicalKeyboardKey.keyM) {
            widget.bus.fire(const ToggleMuteCommand());
          }
          // F: 全屏切换
          else if (key == LogicalKeyboardKey.keyF) {
            widget.bus.fire(const ToggleFullscreenCommand());
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── 视频层（铺满窗口） ───
            ValueListenableBuilder<int?>(
              valueListenable: widget.renderService.textureId,
              builder: (_, textureId, __) {
                return VideoSurface(
                  textureId: textureId,
                  aspectMode: _aspectMode,
                  videoWidth: _videoWidth,
                  videoHeight: _videoHeight,
                );
              },
            ),

            // ─── 控件叠加层（自动显隐） ───
            ControlsOverlay(
              bus: widget.bus,
              isFullscreen: false, // TODO: 从 WindowService 获取
            ),
          ],
        ),
      ),
    );
  }
}
