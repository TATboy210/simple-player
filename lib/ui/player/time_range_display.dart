import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../shared/merged_listenable.dart';

/// 时间显示 (当前 / 总时长)
///
/// 路径B Commit1:数据源从 [EngineStateView] 解耦为 [position]/[duration]
/// ValueListenable。
class TimeRangeDisplay extends StatefulWidget {
  /// 当前位置(ms)。
  final ValueListenable<int> position;

  /// 总时长(ms)。
  final ValueListenable<int> duration;

  const TimeRangeDisplay({
    super.key,
    required this.position,
    required this.duration,
  });

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
    _merged = MergedListenable(widget.position, widget.duration);
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
