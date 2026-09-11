import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/utils/path_utils.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import '../shared/glass_container.dart';
import '../shared/hover_glow.dart';
import '../theme/tokens.dart';

/// 播放列表条目卡 — 缩略图 + 右侧名称/断点信息 (v0.0.5 窄条形态).
///
/// Playlist entry card — thumbnail with play/resume buttons overlaid on it
/// (播放 3/5 + 断点续播 2/5, 盖在缩略图右缘), 名称与上次播放进度在缩略图
/// 右侧. 当前条目以缩略图 accent 描边高亮.
///
/// 缩略图经 [ThumbnailService] 缓存异步加载 (加载中显示占位, 绝不阻断列表滚动).
class PlaylistTile extends StatefulWidget {
  final PlaylistItem item;

  /// 是否为当前正在播放的条目 — 驱动高亮.
  final bool isCurrent;

  /// 点击卡片/播放按钮 → 播放该条目.
  final VoidCallback onPlay;

  /// 断点续播按钮 — 播放并 seek 到 [PlaylistItem.positionMs].
  final VoidCallback onResume;

  /// 右键菜单"移除"动作.
  final VoidCallback onRemove;

  const PlaylistTile({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onPlay,
    required this.onResume,
    required this.onRemove,
  });

  @override
  State<PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<PlaylistTile> {
  ImageProvider? _thumbnail;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant PlaylistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) _loadThumbnail();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 异步取缩略图 — ThumbnailService 内部带 LRU/磁盘缓存与平台降级;
  /// 失败保持占位态, 绝不阻断列表滚动.
  Future<void> _loadThumbnail() async {
    final provider = await ThumbnailService.getThumbnail(widget.item.path);
    if (_disposed || !mounted) return;
    setState(() => _thumbnail = provider);
  }

  /// 断点进度 (0-1) — 无时长或未播放时续播按钮禁用/进度区不显示.
  double? get _resumeProgress {
    final position = widget.item.positionMs ?? 0;
    final duration = widget.item.durationMs ?? 0;
    if (duration <= 0 || position <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final borderColor = widget.isCurrent ? Tokens.accent : Colors.transparent;

    return Tooltip(
      message: widget.item.name,
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: InkWell(
        onTap: widget.onPlay,
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: HoverGlow(
          child: Container(
            padding: const EdgeInsets.all(Tokens.spXs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              border: Border.all(
                color: borderColor,
                width: widget.isCurrent ? 1.5 : 0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 缩略图 — 播放/断点续播按钮盖在其右缘 (用户钦定布局).
                Stack(
                  children: [
                    _buildThumbnail(),
                    Positioned(
                      right: 4,
                      top: 4,
                      bottom: 4,
                      width: _buttonStackWidth,
                      child: _buildOverlayButtons(),
                    ),
                  ],
                ),
                const SizedBox(width: Tokens.spSm),
                // 名称 + 上次播放进度 — 缩略图右侧.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isCurrent
                              ? Tokens.accent
                              : Tokens.textPrimary,
                          fontSize: Tokens.fontCaption,
                        ),
                      ),
                      if (_resumeProgress != null) ...[
                        const SizedBox(height: Tokens.spXs),
                        // 上次播放进度 — 细进度条 + 断点时间.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Tokens.radiusSm,
                          ),
                          child: LinearProgressIndicator(
                            value: _resumeProgress,
                            minHeight: 3,
                            backgroundColor: Colors.black26,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Tokens.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.breakpointAt(
                            formatMs(widget.item.positionMs ?? 0),
                          ),
                          style: const TextStyle(
                            color: Tokens.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// overlay 双按钮列高度 — 缩略图 72 减上下留白.
  static const _buttonStackWidth = 30.0;

  /// 盖在缩略图上的双按钮 — 播放 3/5 + 断点续播 2/5, GlassButton 控制栏同款.
  Widget _buildOverlayButtons() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: GlassButton.iconOnly(
            icon: Icons.play_arrow,
            iconSize: 16,
            tooltip: l10n.play,
            onPressed: widget.onPlay,
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          flex: 2,
          child: GlassButton.iconOnly(
            icon: Icons.replay,
            iconSize: 14,
            tooltip: l10n.resumePlayback,
            onPressed: _resumeProgress == null ? null : widget.onResume,
          ),
        ),
      ],
    );
  }

  /// 缩略图宽度 — 决定条目高度 (16:9 → 72px).
  static const _thumbWidth = 128.0;
  static const _thumbHeight = 72.0;

  /// 16:9 缩略图 — 占位 → 异步图像; 播放中角标.
  Widget _buildThumbnail() {
    return SizedBox(
      width: _thumbWidth,
      height: _thumbHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 占位底色 — 缩略图加载完成前保持视觉占位.
            const ColoredBox(color: Tokens.bgGlass),
            if (_thumbnail != null)
              Image(
                image: _thumbnail!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              const Center(
                child: Icon(
                  Icons.movie_outlined,
                  size: 22,
                  color: Tokens.textSecondary,
                ),
              ),
            // 播放中角标.
            if (widget.isCurrent)
              const Positioned(
                left: 3,
                top: 3,
                child: Icon(
                  Icons.play_circle_fill,
                  size: 14,
                  color: Tokens.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 右键菜单 — 播放 / 打开所在目录 / 移除.
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & (overlay?.size ?? MediaQuery.sizeOf(context)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'play',
          child: ContextMenuRow(Icons.play_arrow, l10n.play),
        ),
        PopupMenuItem<String>(
          value: 'locate',
          child: ContextMenuRow(Icons.folder_open, l10n.openFileLocation),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: ContextMenuRow(Icons.delete_outline, l10n.remove),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'play':
        widget.onPlay();
      case 'locate':
        PathUtils.openFileLocation(widget.item.path);
      case 'remove':
        widget.onRemove();
    }
  }
}
