import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';

/// 缩略图组件 — 16:9 圆角卡片，支持加载占位、播放高亮、断点进度
///
/// 用于沉浸式浮窗的文件夹 tab 和历史 tab。
/// 缩略图来自 [ThumbnailService]（当前 Windows 平台为 no-op）。
///
/// StatelessWidget — 静态布局（label、breakpoint、border）不随加载状态重建。
/// 图片加载隔离到内部 [_ThumbnailImage]。
class ThumbnailTile extends StatelessWidget {
  static const tileWidth = 160.0;
  static const _aspectRatio = 16.0 / 9.0;
  static const _thumbHeight = tileWidth / _aspectRatio;
  static const _nameHeight = 28.0;

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
  Widget build(BuildContext context) {
    final hasBreakpoint =
        (item.positionMs ?? 0) > 0 &&
        item.durationMs != null &&
        item.durationMs! > 0;

    return GestureDetector(
      onTap: onPlay,
      onSecondaryTap: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: tileWidth,
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
      width: tileWidth,
      height: _thumbHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: isCurrent
            ? Border.all(color: Tokens.accent, width: 2)
            : Border.all(color: Tokens.borderHighlight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ThumbnailImage(path: item.path),
            if (isCurrent)
              Container(
                color: Tokens.thumbnailOverlay,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Tokens.accent,
                    size: 32,
                  ),
                ),
              ),
            if (hasBreakpoint && !isCurrent)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BreakpointBar(
                  progress: item.positionMs! / item.durationMs!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameLabel() {
    return SizedBox(
      height: _nameHeight - 4,
      child: Tooltip(
        message: item.name,
        waitDuration: const Duration(milliseconds: Tokens.tooltipDelayLong),
        child: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? Tokens.accent : Tokens.textSecondary,
            fontSize: Tokens.fontOverline,
            fontWeight: isCurrent ? Tokens.weightMedium : Tokens.weightRegular,
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

    final hasBreakpoint = (item.positionMs ?? 0) > 0;
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
          child: ContextMenuRow(Icons.play_arrow, l10n.playAction),
        ),
        if (hasBreakpoint)
          PopupMenuItem(
            value: 'resume',
            child: ContextMenuRow(Icons.play_circle, l10n.resumeAction),
          ),
        PopupMenuItem(
          value: 'openFolder',
          child: ContextMenuRow(Icons.folder_open, l10n.openFileLocation),
        ),
        if (onRemove != null)
          PopupMenuItem(
            value: 'remove',
            child: ContextMenuRow(Icons.delete_outline, l10n.remove),
          ),
        const PopupMenuDivider(),
        if (onShowProperties != null)
          PopupMenuItem(
            value: 'properties',
            child: ContextMenuRow(Icons.info_outline, l10n.properties),
          ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'play':
          onPlay();
          break;
        case 'resume':
          onResume?.call();
          break;
        case 'openFolder':
          PathUtils.openFileLocation(item.path);
          break;
        case 'remove':
          onRemove?.call();
          break;
        case 'properties':
          onShowProperties?.call(item.path);
          break;
      }
    });
  }
}

/// 图片加载 — StatefulWidget 隔离加载状态，path 变化时重建
class _ThumbnailImage extends StatefulWidget {
  final String path;
  const _ThumbnailImage({required this.path});

  @override
  State<_ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<_ThumbnailImage> {
  ImageProvider? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      setState(() {
        _loading = true;
        _thumbnail = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final provider = await ThumbnailService.getThumbnail(widget.path);
    if (!mounted) return;
    if (provider == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (ThumbnailTile.tileWidth * dpr).round();
    setState(() {
      _thumbnail = ResizeImage.resizeIfNeeded(cacheW, null, provider);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
}

class _BreakpointBar extends StatelessWidget {
  final double progress;
  const _BreakpointBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(color: Tokens.progressBarBg),
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
