import 'package:flutter/material.dart';

import '../../core/events/player_events.dart';
import '../../core/state/playback_state.dart';
import '../../infra/event_bus/event_bus.dart';
import '../theme/tokens.dart';

/// MVP 控制栏 — 播放/暂停 + 进度条 + 时间 + 音量 + 全屏
///
/// 纯 UI 组件，所有交互通过 EventBus 命令发送。
class ControlBar extends StatelessWidget {
  final EventBus bus;
  final PlaybackState state;
  final int positionMs;
  final int durationMs;
  final double volume;
  final bool isMuted;
  final bool isFullscreen;

  const ControlBar({
    super.key,
    required this.bus,
    required this.state,
    required this.positionMs,
    required this.durationMs,
    required this.volume,
    required this.isMuted,
    required this.isFullscreen,
  });

  void _fire(PlayerCommand cmd) => bus.fire(cmd);

  @override
  Widget build(BuildContext context) {
    final isPlaying = state == PlaybackState.playing;

    return Container(
      height: Tokens.controlBarHeight,
      margin: const EdgeInsets.fromLTRB(
        Tokens.controlBarMarginH,
        0,
        Tokens.controlBarMarginH,
        Tokens.controlBarMarginBottom,
      ),
      decoration: BoxDecoration(
        color: Tokens.controlBg,
        borderRadius: BorderRadius.circular(Tokens.radiusM),
      ),
      child: Column(
        children: [
          // ─── 进度条 ───
          SizedBox(
            height: Tokens.progressBarHeight,
            child: durationMs > 0
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: const Color(0x33FFFFFF),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value:
                          positionMs.toDouble().clamp(0, durationMs.toDouble()),
                      max: durationMs.toDouble(),
                      onChanged: (v) => _fire(SeekCommand(v.toInt())),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ─── 按钮行 ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // 播放/暂停
                  _ControlButton(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: () => _fire(const TogglePlayPauseCommand()),
                  ),
                  const SizedBox(width: 8),

                  // 上一曲/下一曲
                  _ControlButton(
                    icon: Icons.skip_previous_rounded,
                    size: 20,
                    onTap: () => _fire(const PrevCommand()),
                  ),
                  _ControlButton(
                    icon: Icons.skip_next_rounded,
                    size: 20,
                    onTap: () => _fire(const NextCommand()),
                  ),
                  const SizedBox(width: 8),

                  // 时间显示
                  Text(
                    '${_fmt(positionMs)} / ${_fmt(durationMs)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFeatures: [Tokens.tabularFigures],
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const Spacer(),

                  // 音量按钮（根据 isMuted / volume 切换图标）
                  _ControlButton(
                    icon: isMuted || volume <= 0
                        ? Icons.volume_off_rounded
                        : volume < 50
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 20,
                    onTap: () => _fire(const ToggleMuteCommand()),
                  ),

                  // 全屏按钮（根据 isFullscreen 切换图标）
                  _ControlButton(
                    icon: isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    size: 20,
                    onTap: () => _fire(const ToggleFullscreenCommand()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int ms) {
    if (ms <= 0) return '0:00';
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    this.size = 24,
    required this.onTap,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: Tokens.controlButtonSize,
          height: Tokens.controlButtonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering ? Tokens.controlHover : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusS),
          ),
          child:
              Icon(widget.icon, color: Colors.white, size: widget.size),
        ),
      ),
    );
  }
}
