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
    // ExcludeSemantics 必须位于 VLB **外层** — 排除边界的 RenderObject
    // identity 稳定 (TimeRangeDisplay 自身几乎不 rebuild), 子树语义永不
    // 组装, 每秒文本变化不产生任何语义更新 (AXTree 洪水源消除)。
    // ⚠️ 形态学 (v0.0.9 闪退教训): ExcludeSemantics 若放 builder 内部,
    // 每秒重建排除边界本身 → 引擎语义树"根节点缺失"损坏 → debug CHECK
    // fatal (启动闪退已实证)。identity 稳定是安全前提。
    // 时间信息已由进度条 Semantics (百分比 slider) 承载, 文本级朗读冗余。
    return ExcludeSemantics(
      child: ValueListenableBuilder<TimePair>(
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
      ),
    );
  }
}
