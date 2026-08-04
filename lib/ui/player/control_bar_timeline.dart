import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'control_bar_view_model.dart';
import 'progress_bar.dart';
import 'time_range_display.dart';

/// 控制栏时间导航行：进度条和播放时间共享同一视觉语义。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [ControlBarViewModel]。
class ControlBarTimeline extends StatelessWidget {
  final ControlBarViewModel vm;
  final ValueListenable<bool>? resizing;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const ControlBarTimeline({
    super.key,
    required this.vm,
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
            position: vm.position,
            duration: vm.duration,
            onSeek: vm.onSeek,
            resizing: resizing,
            onSeekStart: onSeekStart,
            onSeekEnd: onSeekEnd,
          ),
        ),
        const SizedBox(width: Tokens.controlBarTimeGap),
        TimeRangeDisplay(position: vm.position, duration: vm.duration),
      ],
    );
  }
}
