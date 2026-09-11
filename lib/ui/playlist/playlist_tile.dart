import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import '../theme/tokens.dart';

/// 播放列表条目卡片 — 16:9 缩略图 + 断点进度条 + 右键菜单 (v0.0.5).
///
/// Playlist entry card — 16:9 thumbnail with resume-progress bar and
/// context menu (play / remove / open file location).
///
/// 数据源为不可变 [PlaylistItem] — 断点/时长随协调器刷新整体重建,
/// 缩略图经 [ThumbnailService] LRU 缓存异步加载 (加载中显示占位).
class PlaylistTile extends StatefulWidget {
  final PlaylistItem item;

  /// 是否为当前正在播放的条目 — 驱动高亮描边.
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

  /// 异步取缩略图 — ThumbnailService 内部带 LRU 缓存与平台降级;
  /// 取消/失败保持占位态, 绝不阻断列表滚动.
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
    final borderColor = widget.isCurrent ? Tokens.accent : Colors.transparent;

    return Tooltip(
      message: widget.item.name,
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: InkWell(
        onTap: widget.onPlay,
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(Tokens.spXs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(
              color: borderColor,
              width: widget.isCurrent ? 1.5 : 0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildThumbnail(),
              const SizedBox(height: Tokens.spXs),
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isCurrent ? Tokens.accent : Tokens.textPrimary,
                  fontSize: 12,
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

  /// 16:9 缩略图区 — 占位 → 异步图像; 断点进度条覆盖在底部.
  Widget _buildThumbnail() {
    final progress = _resumeProgress;
    return AspectRatio(
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
                  size: 28,
                  color: Tokens.textSecondary,
                ),
              ),
            // 播放中角标.
            if (widget.isCurrent)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.play_circle_fill,
                  size: 20,
                  color: Tokens.accent,
                ),
              ),
            // 断点进度条 — 底缘细条, 提示"上次看到这里".
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.black38,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Tokens.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
