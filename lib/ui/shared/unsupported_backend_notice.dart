// UnsupportedBackendNotice — media_kit 后端不支持功能的提示横幅.
//
// media_kit 是唯一后端: EQ/视频效果/字幕延迟等为 stub (空实现 + debugPrint),
// UI 暂留 (保留 Phase 33 成果) 但需明确告知用户调整不生效. 横幅始终渲染.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass_container.dart';

/// media_kit 后端不支持功能的提示横幅.
///
/// 始终渲染警告横幅, 提醒用户当前后端对该功能仅 stub
/// (调整仅保存偏好, 不实际生效).
class UnsupportedBackendNotice extends StatelessWidget {
  const UnsupportedBackendNotice({super.key, this.feature});

  /// 可选功能名, 用于精确描述 (如 "均衡器"/"视频效果").
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final desc = feature == null
        ? '当前后端（media_kit）不支持此功能'
        : '当前后端（media_kit）不支持$feature';

    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      margin: const EdgeInsets.only(bottom: Tokens.spMd),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: Tokens.iconSm,
            color: Tokens.accent,
          ),
          const SizedBox(width: Tokens.spSm),
          Expanded(
            child: Text(
              '$desc，调整仅保存不生效',
              style: const TextStyle(
                color: Tokens.textSecondary,
                fontSize: Tokens.fontOverline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
