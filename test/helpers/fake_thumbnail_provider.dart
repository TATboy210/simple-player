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

/// 合法 64-hex cache key — DiskCache 白名单校验的合法输入。
///
/// [tag] 用两个 hex 字符区分用例（如 'ab'），前缀 0 填充到 64 位。
String hexKey(String tag) => tag.padLeft(64, '0');

/// FakeThumbnailProvider — 服务层测试替身（P-Thumb v1.3.2 §33.1）
///
/// B2 简版：直接返回预置结果。B3 将升级为 completer 版支持乱序控制
/// （§44A）。Fakes over mocks — 手写替身，符合项目测试惯例。
final class FakeThumbnailProvider implements ThumbnailProvider {
  FakeThumbnailProvider({Uint8List? result, this.error})
      : result = result ?? makeJpegBytes();

  Uint8List? result;
  Object? error;
  int calls = 0;

  @override
  Future<Uint8List?> generateThumbnail(String filePath) async {
    calls++;
    final err = error;
    if (err != null) throw err;
    return result;
  }
}
