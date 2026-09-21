/// planPlaylistMoves 纯函数测试 (v0.0.6 Phase 2).
///
/// 含 mpv `playlist-move` 语义模拟器的随机排列 round-trip 属性测试:
/// 落点定律 `from > to → to; from < to → to-1; from == to → no-op`.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/playlist_move_planner.dart';

/// 按 mpv `playlist-move` 真实语义应用命令序列 — 属性测试的裁决模拟器.
List<String> applyMovesMpvSemantics(
  List<String> list,
  List<PlaylistMove> moves,
) {
  final work = [...list];
  for (final move in moves) {
    if (move.from == move.to) continue; // no-op
    final item = work.removeAt(move.from);
    // from < to → 落点 to-1 (目标索引指目标条目, 移除后前移一位);
    // from > to → 落点 to.
    final insertAt = move.from < move.to ? move.to - 1 : move.to;
    work.insert(insertAt, item);
  }
  return work;
}

void main() {
  group('planPlaylistMoves', () {
    test('恒等排列 — 空命令序列', () {
      final moves = planPlaylistMoves(['a', 'b', 'c'], ['a', 'b', 'c']);
      expect(moves, isEmpty);
    });

    test('反转 — 两条命令完成', () {
      final moves = planPlaylistMoves(['a', 'b', 'c'], ['c', 'b', 'a']);
      expect(moves, [
        (from: 2, to: 0), // c → 头部
        (from: 2, to: 1), // b → 第二位 (工作列表此时 [c, a, b])
      ]);
    });

    test('相邻交换 — 单条命令', () {
      final moves = planPlaylistMoves(['a', 'b', 'c'], ['b', 'a', 'c']);
      expect(moves, [(from: 1, to: 0)]);
    });

    test('长度不等 — 空序列防御', () {
      expect(planPlaylistMoves(['a'], ['a', 'b']), isEmpty);
    });

    test('非排列 (元素集合不同) — 空序列防御', () {
      expect(planPlaylistMoves(['a', 'b'], ['a', 'x']), isEmpty);
    });

    test('空队列 — 空序列', () {
      expect(planPlaylistMoves(<String>[], <String>[]), isEmpty);
    });

    test('属性测试 — 随机排列 round-trip 经 mpv 语义模拟器验证', () {
      final rng = Random(20260915); // 固定种子 — 可复现
      for (var round = 0; round < 50; round++) {
        final current = List.generate(
          rng.nextInt(30) + 1,
          (i) => 'item_$i.mp4',
        );
        final target = [...current]..shuffle(rng);

        final moves = planPlaylistMoves(current, target);
        final applied = applyMovesMpvSemantics(current, moves);

        expect(
          applied,
          target,
          reason:
              'round $round: current=$current target=$target '
              'moves=$moves applied=$applied',
        );
      }
    });

    test('属性测试 — 每条命令恒满足 from > to (不变式)', () {
      final rng = Random(42);
      for (var round = 0; round < 50; round++) {
        final current = List.generate(
          rng.nextInt(30) + 1,
          (i) => 'item_$i.mp4',
        );
        final target = [...current]..shuffle(rng);

        for (final move in planPlaylistMoves(current, target)) {
          expect(
            move.from > move.to,
            isTrue,
            reason: 'round $round: $move 违反不变式 — mpv 落点将偏移',
          );
        }
      }
    });
  });
}
