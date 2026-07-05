import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../shared/merged_listenable.dart';

/// 时间显示 (当前 / 总时长)
class TimeRangeDisplay extends StatefulWidget {
  /// Engine state providing [position] and [duration] ValueNotifiers.
  final EngineState engine;

  const TimeRangeDisplay({super.key, required this.engine});

  @override
  State<TimeRangeDisplay> createState() => _TimeRangeDisplayState();
}

class _TimeRangeDisplayState extends State<TimeRangeDisplay> {
  // 使用 MergedListenable 合并 position 和 duration 两个 ValueNotifier
  // 避免分别监听导致多次 rebuild（嵌套 ValueListenableBuilder 会 2x 触发）
  late final MergedListenable _merged;

  @override
  void initState() {
    super.initState();
    _merged = MergedListenable(widget.engine.position, widget.engine.duration);
  }

  @override
  void dispose() {
    _merged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TimePair>(
      valueListenable: _merged,
      builder: (_, pair, _) {
        return Text(
          '${formatMs(pair.a)} / ${formatMs(pair.b)}',
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
            fontFeatures: [Tokens.tabularFigures],
          ),
        );
      },
    );
  }
}
