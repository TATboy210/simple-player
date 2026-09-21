import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_player_flutter/kernel/services/thumbnail_provider.dart';

/// 构造合法 JPEG 骨架 bytes — SOI(FF D8) + payload + EOI(FF D9)
Uint8List makeJpegBytes({int payload = 8, int seed = 0}) {
  final bytes = BytesBuilder()
    ..add([0xFF, 0xD8])
    ..add(List<int>.generate(payload, (i) => (seed + i) % 251));
  bytes.add([0xFF, 0xD9]);
  return bytes.toBytes();
}

/// 最小可解码 1×1 JPEG — Tile 层测试的成功路径需要 Image 真解码成功；
/// [makeJpegBytes] 骨架只通过 SOI/EOI 校验，decode 必炸（errorBuilder 路径用）
final Uint8List realJpegBytes = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof'
  'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh'
  'MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR'
  'CAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAA'
  'AgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkK'
  'FhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWG'
  'h4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl'
  '5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/APn+v//Z',
);

/// 合法 64-hex cache key — DiskCache 白名单校验的合法输入。
///
/// [tag] 用两个 hex 字符区分用例（如 'ab'），前缀 0 填充到 64 位。
/// 注意 tag 只能含 [0-9a-f] — 否则被 `_isSafeHash` 白名单正确拒绝。
String hexKey(String tag) => tag.padLeft(64, '0');

/// FakeThumbnailProvider — 服务层测试替身（P-Thumb v1.3.2 §33.1 / §44A）
///
/// Fakes over mocks — 手写替身，符合项目测试惯例。两种模式：
/// - 即时模式（默认）：generateThumbnail 立即返回 [result]
/// - 乱序模式（[holdJobs] = true）：请求挂入 [jobs]，由测试手动
///   [release]/[failJob] 决定哪个请求先完成 — 覆盖 F4/E1-E6 时序场景
final class FakeThumbnailProvider implements ThumbnailProvider {
  FakeThumbnailProvider({Uint8List? result, this.error})
    : result = result ?? makeJpegBytes();

  Uint8List? result;
  Object? error;

  /// 乱序控制 — true 时请求挂起等待手动收放
  bool holdJobs = false;

  int calls = 0;
  int active = 0;
  int peakActive = 0;

  /// path → 挂起的 job（holdJobs 模式）— FIFO：同 path 多代 job
  /// 依次收放（F4 场景需要先放旧代再放新代）
  final Map<String, Queue<Completer<Uint8List?>>> jobs = {};

  /// 手动放行该 path 最早的挂起 job — bytes 缺省用 [result]
  void release(String filePath, {Uint8List? bytes}) {
    jobs[filePath]?.removeFirst().complete(bytes ?? result);
  }

  /// 手动让该 path 最早的挂起 job 失败 — 模拟 native 异常
  void failJob(String filePath, Object error) {
    jobs[filePath]?.removeFirst().completeError(error);
  }

  /// 手动放行该 path 最早的挂起 job 为 null — 模拟解帧失败返回 null（G3）
  void releaseNull(String filePath) {
    jobs[filePath]?.removeFirst().complete(null);
  }

  @override
  Future<Uint8List?> generateThumbnail(String filePath) async {
    calls++;
    active++;
    if (active > peakActive) peakActive = active;
    try {
      final err = error;
      if (err != null) throw err;

      if (holdJobs) {
        final completer = Completer<Uint8List?>();
        jobs.putIfAbsent(filePath, () => Queue()).addLast(completer);
        return await completer.future;
      }
      return result;
    } finally {
      active--;
    }
  }
}
