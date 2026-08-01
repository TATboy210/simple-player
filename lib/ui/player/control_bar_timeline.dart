import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import 'progress_bar.dart';
import 'time_range_display.dart';

/// 控制栏时间导航行：进度条和播放时间共享同一视觉语义。
class ControlBarTimeline extends StatelessWidget {
  final MediaEngine engine;
  final ValueListenable<bool>? resizing;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const ControlBarTimeline({
    super.key,
    required this.engine,
    this.resizing,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProgressBar(
            engine: engine,
            resizing: resizing,
            onSeekStart: onSeekStart,
            onSeekEnd: onSeekEnd,
          ),
        ),
        const SizedBox(width: Tokens.controlBarTimeGap),
        TimeRangeDisplay(engine: engine),
      ],
    );
  }
}
