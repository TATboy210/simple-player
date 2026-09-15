/// shuffle 播放顺序策略 — 随机覆盖层的纯函数层 (v0.0.6).
///
/// Shuffle playback-order policy — pure logic for the random overlay.
///
/// 设计裁决 (v0.0.6): 随机 = **播放顺序覆盖层**, mpv playlist 永不物理
/// 乱序 (media_kit `setShuffle` 底层是 mpv `playlist-shuffle` 物理重排,
/// 已弃用). 本文件只回答一个问题: "下一曲随机到哪" — 列表排列、
/// 排序方式、持久化顺序均与本层无关.
library;

import 'dart:collection';
import 'dart:math';

/// shuffle 策略 — 无状态纯函数集合.
abstract final class ShufflePolicy {
  /// 播放历史栈容量 — previous 回溯的最大深度; 溢出丢栈底 (最旧).
  static const int historyCapacity = 32;

  /// 随机选下一曲.
  ///
  /// - 排除当前曲;
  /// - 避开最近播放集 [recent] (栈顶在前), 鸽笼保证: 避开集最多取
  ///   `pool.length - 1` 个 → 恒有"新鲜"候选, 2 元素小队列不死锁;
  /// - 队列只有当前曲 (无处可跳) 返回 null, 调用方裁定回退 (通常重播).
  static String? pickShuffleNext({
    required List<String> queue,
    required String? current,
    required List<String> recent,
    required Random random,
  }) {
    final pool = queue.where((p) => p != current).toList();
    if (pool.isEmpty) return null;
    final avoid = recent.take(pool.length - 1).toSet();
    final fresh = pool.where((p) => !avoid.contains(p)).toList();
    final candidates = fresh.isNotEmpty ? fresh : pool;
    return candidates[random.nextInt(candidates.length)];
  }

  /// 入栈播放历史 — 超容量丢栈底.
  static void pushHistory(ListQueue<String> history, String path) {
    history.addLast(path);
    while (history.length > historyCapacity) {
      history.removeFirst();
    }
  }
}
