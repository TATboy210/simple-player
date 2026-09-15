/// mpv playlist-move 命令规划器 — 队列物理重排的纯函数层 (v0.0.6).
///
/// mpv playlist-move command planner — pure logic for physical queue reorder.
///
/// mpv `playlist-move <from> <to>` 落点定律 (mpv.io/manual 查证):
/// - `from > to` → 条目落在索引 `to`
/// - `from < to` → 条目落在索引 `to - 1` (目标索引指目标条目, 移除后前移)
/// - `from == to` → no-op
///
/// [planPlaylistMoves] 用插入排序式规划保证每条命令恒满足 `from > to`,
/// 从而 `from < to` 的陷阱分支不可达, 落点恰为 `to` — 语义坑被算法不变式
/// 消化, 无需特判.
library;

/// 一条 mpv `playlist-move` 命令 — from/to 为执行时刻的队列索引.
typedef PlaylistMove = ({int from, int to});

/// 计算把 [current] 重排为 [target] 所需的命令序列 (按序执行).
///
/// requires: [target] 是 [current] 的排列（同元素集合、同长度）;
/// 违反时返回空序列（no-op 防御 — 排序请求与引擎镜像间的竞态
/// 由"以调用时刻快照为准"消化）.
List<PlaylistMove> planPlaylistMoves(List<String> current, List<String> target) {
  if (current.length != target.length) return const [];
  final currentSet = current.toSet();
  if (currentSet.length != target.length ||
      !currentSet.containsAll(target)) {
    return const []; // 非排列 (元素缺失/重复) — 防御
  }

  final work = [...current];
  final moves = <PlaylistMove>[];
  for (var i = 0; i < target.length; i++) {
    final want = target[i];
    // 不变式: work[0..i) 已与 target[0..i) 一致 ⇒ want 不在前缀中
    // ⇒ j >= i 恒成立; j == i 跳过; j > i 即 from > to.
    final j = work.indexOf(want);
    if (j == i) continue;
    moves.add((from: j, to: i));
    work.removeAt(j);
    work.insert(i, want);
  }
  return moves;
}
