import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import '../theme/tokens.dart';
import '../shared/hover_glow.dart';

/// 播放列表条目卡 — 横向布局: 缩略图左 + 断点信息右 (v0.0.5 竖条形态).
///
/// Playlist entry card — horizontal layout (thumbnail left, resume info
/// right) for the side-panel list. 当前条目以左侧 accent 竖条 + 标题着色
/// 高亮; 断点以细进度条呈现"上次看到这里".
///
/// 数据源为不可变 [PlaylistItem]; 缩略图经 [ThumbnailService] 缓存异步
/// 加载 (加载中显示占位, 绝不阻断列表滚动).
class PlaylistTile extends StatefulWidget {
  final PlaylistItem item;

  /// 是否为当前正在播放的条目 — 驱动高亮.
  final bool isCurrent;

  /// 点击卡片 → 播放该条目.
  final VoidCallback onPlay;

  /// 右键菜单"移除"动作.
  final VoidCallback onRemove;

  const PlaylistTile({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onPlay,
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

  /// 断点进度 (0-1) — 无时长或未播放时不显示进度条.
  double? get _resumeProgress {
    final position = widget.item.positionMs ?? 0;
    final duration = widget.item.durationMs ?? 0;
    if (duration <= 0 || position <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            // 当前条目左侧 accent 竖条高亮 — 视觉锚点不依赖边框.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              border: Border(
                left: BorderSide(
                  color: widget.isCurrent
                      ? Tokens.accent
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildThumbnail(),
                const SizedBox(width: Tokens.spSm),
                Expanded(child: _buildInfo(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 信息列 — 标题 + 断点细进度条.
  Widget _buildInfo(AppLocalizations l10n) {
    final progress = _resumeProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.isCurrent ? Tokens.accent : Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        const SizedBox(height: Tokens.spXs),
        // 断点细进度条 — 有断点才显示, 提示"上次看到这里".
        progress == null
            ? const SizedBox.shrink()
            : ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.black26,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Tokens.accent,
                  ),
                ),
              ),
      ],
    );
  }

  /// 16:9 缩略图 — 占位 → 异步图像; 播放中叠加角标.
  Widget _buildThumbnail() {
    return SizedBox(
      width: 112,
      child: AspectRatio(
        aspectRatio: 16 / 9,
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
                    size: 24,
                    color: Tokens.textSecondary,
                  ),
                ),
              // 播放中角标.
              if (widget.isCurrent)
                const Positioned(
                  right: 3,
                  top: 3,
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 16,
                    color: Tokens.accent,
                  ),
                ),
            ],
          ),
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
