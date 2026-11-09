import 'package:flutter/material.dart';

import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'playlist_tokens.dart';

/// 条目右侧信息区 — 名称 (+ 失败重试入口) + 上次播放进度条与断点时间.
///
/// Right-hand info column of a playlist entry: name row (with the 24px
/// retry hot-zone, §27.2, located outside the thumbnail so it never covers
/// the film buttons) plus the thin resume progress bar and breakpoint time.
class PlaylistTileInfo extends StatelessWidget {
  /// 创建信息区.
  const PlaylistTileInfo({
    super.key,
    required this.name,
    required this.nameColor,
    required this.showRetry,
    required this.onRetry,
    required this.resumeProgress,
    required this.positionMs,
  });

  /// 条目名称.
  final String name;

  /// 名称色 — 与条目高亮色同源.
  final Color nameColor;

  /// 是否显示失败重试入口.
  final bool showRetry;

  /// 点击重试回调.
  final VoidCallback onRetry;

  /// 断点进度 (0-1); null = 不显示进度区.
  final double? resumeProgress;

  /// 断点毫秒数 (进度区显示的时间).
  final int positionMs;

  @override
  Widget build(BuildContext context) {
    final progress = resumeProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 名称 + 失败重试入口同行 — 重试 24px 热区（§27.2）.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: nameColor,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
            if (showRetry) PlaylistRetryButton(onPressed: onRetry),
          ],
        ),
        if (progress != null) ..._resumeSection(context, progress),
      ],
    );
  }

  /// 上次播放进度 — 细进度条 + 断点时间.
  List<Widget> _resumeSection(BuildContext context, double progress) {
    return [
      const SizedBox(height: Tokens.spXs),
      ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: PlaylistTokens.resumeBarHeight,
          backgroundColor: Colors.black26,
          valueColor: const AlwaysStoppedAnimation<Color>(Tokens.accent),
        ),
      ),
      const SizedBox(height: PlaylistTokens.resumeBarGap),
      Text(
        AppLocalizations.of(context).breakpointAt(formatMs(positionMs)),
        style: const TextStyle(
          color: Tokens.textSecondary,
          fontSize: PlaylistTokens.breakpointFontSize,
        ),
      ),
    ];
  }
}

/// 失败重试入口 — 24px 热区 icon-only（refresh 语义自明），位于名称行
/// 右侧，不改变 Tile 总高度（§27.1）.
class PlaylistRetryButton extends StatelessWidget {
  /// 创建重试按钮.
  const PlaylistRetryButton({super.key, required this.onPressed});

  /// 点击回调 (同步签名 — 调用方自行 unawaited 异步重试).
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Tokens.iconButtonSizeSmall,
      height: Tokens.iconButtonSizeSmall,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(
          Icons.refresh_outlined,
          size: PlaylistTokens.retryIconSize,
          color: Tokens.textSecondary,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: Tokens.iconButtonSizeSmall,
          minHeight: Tokens.iconButtonSizeSmall,
        ),
      ),
    );
  }
}
