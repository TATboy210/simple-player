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
        // ExcludeSemantics (v0.0.9 内存/卡顿治理): 本文本每秒变化, 若暴露
        // 语义则每秒触发 controls 子树整树语义重序列化 — 撞上
        // accessibility_bridge 的已知序列化 bug (flutter #113741/#173118,
        // "Nodes left pending by the update") 形成错误洪流, 白烧主线程
        // 并推高 RSS。时间信息已由进度条 Semantics (百分比 slider) 承载,
        // 文本级时间朗读是冗余通道。
        return ExcludeSemantics(
          child: Text(
            '${formatMs(pair.a)} / ${formatMs(pair.b)}',
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
              fontFeatures: [Tokens.tabularFigures],
            ),
          ),
        );
      },
    );
  }
}
