import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';

/// 视频纹理渲染 — 根据引擎 textureId 和 aspectRatio 显示视频
///
/// 手势由 ControlsOverlay 统一处理（tap 隐藏 / double-tap 全屏）。
/// 此组件仅负责渲染纹理 + 滚轮音量调节。
class VideoSurface extends StatelessWidget {
  final MediaEngine engine;

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
          return SizedBox.expand(
            child: id == null
                ? const SizedBox.shrink()
                : Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
                        final v = (engine.volume.value + delta).clamp(0.0, 1.0);
                        engine.setVolume(v);
                      }
                    },
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: safeRatio >= 1 ? safeRatio * 1000 : 1000,
                        height: safeRatio >= 1 ? 1000 : 1000 / safeRatio,
                        child: Texture(textureId: id),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
