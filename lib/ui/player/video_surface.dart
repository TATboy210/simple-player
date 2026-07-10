import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';

/// 视频纹理渲染 — 根据引擎 textureId 和 aspectRatio 显示视频
///
/// 手势由 ControlsOverlay 统一处理（tap 隐藏 / double-tap 全屏）。
/// 此组件仅负责渲染纹理 + 滚轮音量调节。
/// Listener 提升到 AnimatedBuilder 外层，避免每次纹理重建时重建回调。
class VideoSurface extends StatelessWidget {
  final EngineState engine;

  const VideoSurface({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([engine.textureId, engine.aspectRatio]),
        builder: (_, _) {
          final id = engine.textureId.value;
          final ratio = engine.aspectRatio.value;
          final safeRatio = (ratio > 0 && ratio.isFinite) ? ratio : 16 / 9;
          // 诊断日志: 记录视频宽高比 (全屏黑边排查用)
          debugPrint(
            '[VideoSurface] textureId=$id, ratio=${ratio.toStringAsFixed(3)}, '
            'safeRatio=${safeRatio.toStringAsFixed(3)}',
          );
          return SizedBox.expand(
            child: id == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: safeRatio >= 1 ? safeRatio * 1000 : 1000,
                      height: safeRatio >= 1 ? 1000 : 1000 / safeRatio,
                      child: Texture(textureId: id),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
