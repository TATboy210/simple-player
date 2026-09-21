import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

import 'thumbnail_provider.dart';

/// Windows 缩略图 Provider — Media Foundation 解帧 + WIC 编码（P-Thumb v1.3.2 §24）
///
/// Windows thumbnail provider — frame extraction via Media Foundation
/// ([FlutterVideoThumbnailPlus]), returning raw JPEG bytes.
///
/// v1.3.2 职责边界（B2）：磁盘缓存已上移至 Service 层 ThumbnailDiskCache —
/// Provider 不再决定 cache identity、不写盘、不返回 ImageProvider（I7）。
///
/// 依赖选型 (v0.0.5, fc_native_video_thumbnail 已弃): 前者走 Windows Shell
/// 缩略图缓存, 对缓存 miss/特殊容器会 WTS_E_FAILEDEXTRACTION; 本包走
/// Media Foundation 系统解码器直接解帧, 与播放器解码能力同源.
class WindowsThumbnailProvider implements ThumbnailProvider {
  const WindowsThumbnailProvider();

  /// 缩略图最长边 — 列表卡片 16:9 显示足够, 解帧开销最小化.
  /// 与 _ThumbnailSpec.maxWidth 冻结值一致 — 规格变更必须同步换 schema 版本.
  static const _maxSize = 320;

  /// 截帧时间点 (ms) — 取 1s 处避开常见黑屏首帧; 超出时长的短视频由
  /// Media Foundation 收敛到末帧.
  static const _timeMs = 1000;

  @override
  Future<Uint8List?> generateThumbnail(String filePath) async {
    try {
      return await FlutterVideoThumbnailPlus.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.jpeg,
        maxWidth: _maxSize,
        maxHeight: _maxSize,
        timeMs: _timeMs,
        quality: 85,
      );
    } on Exception {
      // 解帧失败（损坏文件/不支持的容器）— null 由 UI 占位呈现,
      // native 异常绝不穿透到 UI（§24.4）
      return null;
    }
  }
}
