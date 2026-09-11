import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import '../shared/hover_glow.dart';
import '../theme/tokens.dart';

/// 播放列表条目卡 — 缩略图 + 右侧双按钮列 (v0.0.5 窄条形态, 用户钦定布局).
///
/// Playlist entry card — thumbnail with overlaid name, plus a vertical
/// button stack on the right: 播放按钮 (3/5 高) 上, 断点续播按钮 (2/5 高) 下.
/// 无断点的条目续播按钮禁用; 当前条目以缩略图 accent 描边高亮.
///
/// 缩略图经 [ThumbnailService] 缓存异步加载 (加载中显示占位, 绝不阻断列表滚动).
class PlaylistTile extends StatefulWidget {
  final PlaylistItem item;

  /// 是否为当前正在播放的条目 — 驱动高亮.
  final bool isCurrent;

  /// 点击卡片/播放按钮 → 从头播放该条目.
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

  /// 断点进度 (0-1) — 无时长或未播放时续播按钮禁用.
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
              // 固定尺寸布局 — 缩略图 128×72 (16:9), 按钮列 44×72:
              // ListView 给条目无界高度, 尺寸必须自洽 (Expanded 会爆炸).
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThumbnail(),
                const SizedBox(width: Tokens.spXs),
                // 双按钮列 — 播放 3/5 + 断点续播 2/5 (与缩略图同高).
                SizedBox(
                  width: 44,
                  height: _thumbHeight,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SideButton(
                          icon: Icons.play_arrow,
                          tooltip: l10n.play,
                          onPressed: widget.onPlay,
                          accent: widget.isCurrent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        flex: 2,
                        child: _SideButton(
                          icon: Icons.replay,
                          tooltip: l10n.resumePlayback,
                          onPressed: _resumeProgress == null
                              ? null
                              : widget.onResume,
                        ),
                      ),
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

  /// 缩略图宽度 — 决定条目高度 (16:9 → 72px), 与按钮列同高.
  static const _thumbWidth = 128.0;
  static const _thumbHeight = 72.0;

  /// 16:9 缩略图 — 占位 → 异步图像; 名称 overlay 底部; 播放中角标.
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
            // 名称 overlay — 底部半透明条, 单行省略.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // 播放中角标.
            if (widget.isCurrent)
              const Positioned(
                right: 3,
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

/// 条目侧边小按钮 — 紧凑玻璃质感, 铺满分配空间.
class _SideButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 当前条目高亮态 — 图标着 accent 色.
  final bool accent;

  const _SideButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: Material(
        color: Tokens.bgGlass,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? Tokens.textSecondary.withValues(alpha: 0.4)
                  : accent
                  ? Tokens.accent
                  : Tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
