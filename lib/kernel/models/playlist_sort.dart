/// 播放列表排序键与比较器 — 排序方式的纯逻辑层 (v0.0.6).
///
/// Playlist sort keys and comparator — pure logic for playlist sorting.
///
/// 设计裁决 (v0.0.6): 排序 = 用户显式意图的**物理重排**（经
/// `QueueControl.sortQueue` → mpv `playlist-move`），显示顺序 = 播放顺序 =
/// 持久化顺序，单一索引空间。与播放顺序（[PlayMode.shuffle] 随机覆盖层）
/// 严格分离 — 随机永不改变列表排列。
library;

import 'playlist_item.dart';

/// 播放列表排序键.
enum PlaylistSortKey {
  /// 添加顺序（默认）— 按 [PlaylistItem.addedSeq] 升降序.
  addedOrder,

  /// 按文件名 — 自然序 (file2 < file10, 资源管理器惯例), 大小写不敏感.
  name,

  /// 按最后播放时间 — null (从未播放) 视作最旧.
  lastPlayed,

  /// 按时长 — null (未知) 恒排末尾, 方向无关.
  duration,
}

/// 排序比较器 — 返回负值表示 [a] 应排在 [b] 之前.
///
/// Contract:
/// - `addedOrder` / `duration`: null 值恒排末尾（升降序无关）.
/// - `lastPlayed`: null = 从未播放 = 最旧（随升降序移动）.
/// - 平局一律按 path 自然序 tie-break（稳定、可复现）.
int comparePlaylistEntries(
  PlaylistItem a,
  PlaylistItem b, {
  required PlaylistSortKey key,
  required bool ascending,
}) {
  switch (key) {
    case PlaylistSortKey.addedOrder:
      final primary = _compareOptInt(a.addedSeq, b.addedSeq);
      return primary ?? _tiebreak(a, b);
    case PlaylistSortKey.name:
      final primary = _naturalCompare(
        a.name.toLowerCase(),
        b.name.toLowerCase(),
      );
      return primary != 0 ? (ascending ? primary : -primary) : _tiebreak(a, b);
    case PlaylistSortKey.lastPlayed:
      // null = 从未播放 = 最旧 (epoch 0) — 方向相关语义.
      final at = a.timestamp ?? 0;
      final bt = b.timestamp ?? 0;
      if (at != bt) {
        return ascending ? (at < bt ? -1 : 1) : (at < bt ? 1 : -1);
      }
      return _tiebreak(a, b);
    case PlaylistSortKey.duration:
      final primary = _compareOptInt(a.durationMs, b.durationMs);
      return primary ?? _tiebreak(a, b);
  }
}

/// null 恒排末尾 (方向无关); 双非 null 升序比较; 双 null 返回 null (交由
/// 调用方 tie-break).
int? _compareOptInt(int? x, int? y) {
  if (x == null && y == null) return null;
  if (x == null) return 1; // a 排 b 后
  if (y == null) return -1;
  return x < y ? -1 : (x > y ? 1 : 0);
}

/// 平局裁决 — path 自然序恒升序 (稳定次级键, 方向无关).
int _tiebreak(PlaylistItem a, PlaylistItem b) =>
    _naturalCompare(a.path.toLowerCase(), b.path.toLowerCase());

/// 自然序比较 — 数字段按数值比较 (file2 < file10), 其余按码元比较.
///
/// Windows 资源管理器惯例: 带编号的文件按人的预期排序, 而非纯字典序.
int _naturalCompare(String x, String y) {
  var i = 0;
  var j = 0;
  while (i < x.length && j < y.length) {
    final xDigit = _isDigit(x.codeUnitAt(i));
    final yDigit = _isDigit(y.codeUnitAt(j));
    if (xDigit && yDigit) {
      // 各读出完整数字段, 去前导零后先比长度再比字典序 —
      // 避免 int.parse 溢出, 支持任意长数字段.
      var i2 = i;
      while (i2 < x.length && _isDigit(x.codeUnitAt(i2))) {
        i2++;
      }
      var j2 = j;
      while (j2 < y.length && _isDigit(y.codeUnitAt(j2))) {
        j2++;
      }
      final xs = _stripLeadingZeros(x.substring(i, i2));
      final ys = _stripLeadingZeros(y.substring(j, j2));
      if (xs.length != ys.length) return xs.length < ys.length ? -1 : 1;
      final cmp = xs.compareTo(ys);
      if (cmp != 0) return cmp;
      i = i2;
      j = j2;
      continue;
    }
    final xc = x.codeUnitAt(i);
    final yc = y.codeUnitAt(j);
    if (xc != yc) return xc < yc ? -1 : 1;
    i++;
    j++;
  }
  // 前缀短者在前.
  if (i < x.length) return 1;
  if (j < y.length) return -1;
  return 0;
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// 去前导零 — 全零段返回空串 (空串 < 任何非空段, "0" < "00" < "1" 语义合理).
String _stripLeadingZeros(String s) {
  var start = 0;
  while (start < s.length - 1 && s.codeUnitAt(start) == 0x30) {
    start++;
  }
  return s.substring(start);
}
