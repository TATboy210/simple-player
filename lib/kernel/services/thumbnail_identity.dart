/// 缩略图规格与文件身份 — 冻结参数 + canonical 串 + cacheKey (从 ThumbnailService 拆出).
///
/// Frozen extraction spec, identity snapshot and key derivation (P-Thumb
/// v1.3.2 §10-§12). Pure functions: no I/O, no state.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 缩略图规格 — 冻结的解帧参数（P-Thumb v1.3.2 §10.2）
///
/// Frozen extraction parameters. Every field enters the canonical cache-key
/// string, so changing any value (or [schemaVersion]) rotates all keys at
/// once — stale cached thumbnails can never be served after an upgrade.
final class ThumbnailSpec {
  const ThumbnailSpec._();

  /// 缓存架构版本 — 整体换 key 的总闸，旧 v2 磁盘文件由后台清理回收
  static const schemaVersion = 'v3';

  /// 解帧最长边 — 列表卡片 128×72 显示足够
  static const maxWidth = 320;

  /// 解帧最大高度 — 与 [maxWidth] 同值 (等比缩放, 取长边约束).
  static const maxHeight = 320;

  /// 截帧时间点 (ms) — 取 1s 处避开常见黑屏首帧
  static const timeMs = 1000;

  /// JPEG 编码质量 (0-100).
  static const jpegQuality = 85;
}

/// 文件身份 — immutable snapshot（P-Thumb v1.3.2 §10.1）
///
/// Identity snapshot `(normalized path, size, mtime, spec)` hashed into a
/// cache key. Resolved once per request; async stages must never re-stat
/// or mutate it — they consume the same instance.
final class ThumbnailIdentity {
  /// 创建身份快照.
  const ThumbnailIdentity({required this.path, required this.cacheKey});

  /// normalize 后的绝对路径 — 传给 provider 的唯一形态
  final String path;

  /// sha256(canonical) — 内存 LRU 与磁盘文件名共用的主键
  final String cacheKey;
}

/// 组装 identity — size + mtime 进入 canonical，防止源文件替换后命中旧图.
ThumbnailIdentity buildThumbnailIdentity(
  String path,
  int size,
  int modifiedMs,
) {
  final canonical = buildCanonicalString(
    schemaVersion: ThumbnailSpec.schemaVersion,
    path: path,
    size: size,
    modifiedMs: modifiedMs,
  );
  return ThumbnailIdentity(
    path: path,
    cacheKey: cacheKeyFromCanonical(canonical),
  );
}

/// canonical 身份串 — NUL 分隔防字段拼接歧义（§12.4）。
///
/// 分隔符歧义前提是 path 含 NUL — Windows/POSIX 文件名均由 OS 禁止，
/// 无需额外防御。实现用 [String.fromCharCode] 构造分隔符，
/// 避免转义字面量以真实 NUL 字节进入源文件。
String buildCanonicalString({
  required String schemaVersion,
  required String path,
  required int size,
  required int modifiedMs,
  int maxWidth = ThumbnailSpec.maxWidth,
  int maxHeight = ThumbnailSpec.maxHeight,
  int timeMs = ThumbnailSpec.timeMs,
  String format = 'jpeg',
  int quality = ThumbnailSpec.jpegQuality,
}) {
  final sep = String.fromCharCode(0x00);
  return '$schemaVersion$sep'
      '$path$sep'
      '$size$sep'
      '$modifiedMs$sep'
      '$maxWidth$sep'
      '$maxHeight$sep'
      '$timeMs$sep'
      '$format$sep'
      '$quality';
}

/// canonical → cacheKey — SHA-256 hex（64 字符）。
///
/// hash 只做缓存文件名身份，不是认证边界；输入仅几十到几百字节，
/// SHA-256 相比 MD5 的额外开销可忽略但抗恶意碰撞更强（§12.3）。
String cacheKeyFromCanonical(String canonical) {
  return sha256.convert(utf8.encode(canonical)).toString();
}
