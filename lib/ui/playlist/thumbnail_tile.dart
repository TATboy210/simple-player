import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';

/// 缩略图组件 — 16:9 圆角卡片，支持加载占位、播放高亮、断点进度
///
/// 用于沉浸式浮窗的文件夹 tab 和历史 tab。
/// 缩略图来自 [ThumbnailService]（Win32 COM 系统缩略图）。
class ThumbnailTile extends StatefulWidget {
  final PlaylistItem item;
  final bool isCurrent;
  final VoidCallback onPlay;
  final VoidCallback? onResume;
  final VoidCallback? onRemove;
  final void Function(String path)? onShowProperties;

  const ThumbnailTile({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onPlay,
    this.onResume,
    this.onRemove,
    this.onShowProperties,
  });

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile> {
  static const _tileWidth = 160.0;
  static const _aspectRatio = 16.0 / 9.0;
  static const _thumbHeight = _tileWidth / _aspectRatio;
  static const _nameHeight = 28.0;

  ImageProvider? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant ThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _loading = true;
      _thumbnail = null;
    });
    final provider = await ThumbnailService.getThumbnail(widget.item.path);
    if (!mounted) return;
    setState(() {
      _thumbnail = provider;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBreakpoint = (widget.item.positionMs ?? 0) > 0 &&
        widget.item.durationMs != null &&
        widget.item.durationMs! > 0;

    return GestureDetector(
      onTap: widget.onPlay,
      onSecondaryTap: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThumbnail(hasBreakpoint),
              const SizedBox(height: 4),
              _buildNameLabel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool hasBreakpoint) {
    return Container(
      width: _tileWidth,
      height: _thumbHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: widget.isCurrent
            ? Border.all(color: Tokens.accent, width: 2)
            : Border.all(color: Tokens.borderHighlight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图 or 占位符
            _buildImage(),
            // 播放中图标覆盖
            if (widget.isCurrent)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Tokens.accent,
                    size: 32,
                  ),
                ),
              ),
            // 断点进度条覆盖
            if (hasBreakpoint && !widget.isCurrent)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BreakpointBar(
                  progress: widget.item.positionMs! / widget.item.durationMs!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_loading) {
      return Container(
        color: Tokens.bgHover,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Tokens.textDisabled,
            ),
          ),
        ),
      );
    }
    if (_thumbnail != null) {
      return Image(
        image: _thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Tokens.bgHover,
      child: const Center(
        child: Icon(Icons.movie, color: Tokens.textDisabled, size: 28),
      ),
    );
  }

  Widget _buildNameLabel() {
    return SizedBox(
      height: _nameHeight - 4,
      child: Tooltip(
        message: widget.item.name,
        waitDuration: const Duration(milliseconds: 600),
        child: Text(
          widget.item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.isCurrent ? Tokens.accent : Tokens.textSecondary,
            fontSize: Tokens.fontOverline,
            fontWeight:
                widget.isCurrent ? Tokens.weightMedium : Tokens.weightRegular,
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final hasBreakpoint = (widget.item.positionMs ?? 0) > 0;
    final l10n = AppLocalizations.of(context);

    showMenu<String>(
      context: context,
      position: position,
      color: Tokens.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      ),
      items: [
        PopupMenuItem(
          value: 'play',
          child: _MenuItemRow(Icons.play_arrow, l10n.playAction),
        ),
        if (hasBreakpoint)
          PopupMenuItem(
            value: 'resume',
            child: _MenuItemRow(Icons.play_circle, l10n.resumeAction),
          ),
        PopupMenuItem(
          value: 'openFolder',
          child: _MenuItemRow(Icons.folder_open, l10n.openFileLocation),
        ),
        if (widget.onRemove != null)
          PopupMenuItem(
            value: 'remove',
            child: _MenuItemRow(Icons.delete_outline, l10n.remove),
          ),
        const PopupMenuDivider(),
        if (widget.onShowProperties != null)
          PopupMenuItem(
            value: 'properties',
            child: _MenuItemRow(Icons.info_outline, l10n.properties),
          ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'play':
          widget.onPlay();
          break;
        case 'resume':
          widget.onResume?.call();
          break;
        case 'openFolder':
          _openFileLocation();
          break;
        case 'remove':
          widget.onRemove?.call();
          break;
        case 'properties':
          widget.onShowProperties?.call(widget.item.path);
          break;
      }
    });
  }

  void _openFileLocation() {
    PathUtils.openFileLocation(widget.item.path);
  }
}

class _BreakpointBar extends StatelessWidget {
  final double progress;
  const _BreakpointBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        color: Color(0x44000000),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Tokens.accent.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItemRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: Tokens.iconMd, color: Tokens.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ],
    );
  }
}

