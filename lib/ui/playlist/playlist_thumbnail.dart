import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'playlist_tokens.dart';

/// 缩略图三态（P-Thumb v1.3.2 §26）— loading/ready/failed 驱动占位与重试入口.
enum PlaylistThumbPhase { loading, ready, failed }

/// loading/failed 共用占位 — 电影 icon（§27.1：不为 loading 加独立
/// spinner 噪音；failed 的重试入口在名称行）.
class PlaylistThumbPlaceholder extends StatelessWidget {
  /// 创建占位图标.
  const PlaylistThumbPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        size: PlaylistTokens.placeholderIconSize,
        color: Tokens.textSecondary,
      ),
    );
  }
}

/// 16:9 缩略图三态渲染（§27.1）— 占位 → 异步图像; ready 按 Tile 物理
/// 宽度解码降内存（§14A.2：显示不变，decoded 工作集 ~230→~144 KiB/张）.
///
/// 261009-o8z T5: 占位图标恒在 Stack 底层, ready 成图经
/// TweenAnimationBuilder ~150ms 淡入覆盖 — 消除占位→成图同帧硬切的
/// 弹现感; 淡入期间占位从成图底下透出是需求本身.
class PlaylistThumbnail extends StatelessWidget {
  /// 创建缩略图.
  const PlaylistThumbnail({
    super.key,
    required this.thumbnail,
    required this.phase,
    required this.onDecodeFailed,
  });

  /// 已加载的图像 provider (null = 尚无/失败).
  final ImageProvider? thumbnail;

  /// 当前加载阶段.
  final PlaylistThumbPhase phase;

  /// 图像解码失败回调 — errorBuilder 在 build 期间触发, 调用方须自行
  /// post-frame 回写状态.
  final VoidCallback onDecodeFailed;

  @override
  Widget build(BuildContext context) {
    final provider = thumbnail;
    final isReady = phase == PlaylistThumbPhase.ready;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 占位底色 — 缩略图加载完成前保持视觉占位.
          const ColoredBox(color: Tokens.bgGlass),
          // 占位图标恒在底层（不再条件化）— ready 淡入期间从底下透出.
          const PlaylistThumbPlaceholder(),
          if (isReady && provider != null) _fadeInImage(context, provider),
        ],
      ),
    );
  }

  /// 单次插值淡入 — 无常驻 AnimationController; 挂载即从 0 起步,
  /// retry/重载触发重挂载时自动二次淡入. DPR 变化换图不重挂载
  /// (gaplessPlayback), TweenAnimationBuilder 不重建 → 不重播.
  Widget _fadeInImage(BuildContext context, ImageProvider provider) {
    // 单轴 width 保持纵横比 — 128 logical × DPR，clamp 128..320.
    final decodeWidth =
        (PlaylistTokens.thumbWidth * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(
              PlaylistTokens.thumbWidth.toInt(),
              PlaylistTokens.maxDecodeWidth,
            )
            .toInt();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: Tokens.durationNormal),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Image(
        image: ResizeImage(provider, width: decodeWidth),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) {
          // bytes 损坏等解码失败 — 立即占位 + 调用方 post-frame 揭示重试入口.
          onDecodeFailed();
          return const PlaylistThumbPlaceholder();
        },
      ),
    );
  }
}
