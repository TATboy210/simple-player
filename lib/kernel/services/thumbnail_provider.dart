import 'package:flutter/painting.dart';

/// 缩略图提供者抽象接口 — 平台无关。
///
/// 每个平台实现负责从文件路径提取系统缩略图。
/// 缓存由 [ThumbnailService] 门面统一管理，实现层无需关心。
abstract interface class ThumbnailProvider {
  /// 获取文件的系统缩略图。失败时返回 null。
  Future<ImageProvider?> getThumbnail(String filePath);
}
