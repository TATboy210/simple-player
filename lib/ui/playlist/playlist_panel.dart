import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import 'playlist_tile.dart';

/// 播放列表浮窗面板 — 玻璃质感网格缩略图 + 播放模式切换 (v0.0.5 精简 v1).
///
/// Immersive floating playlist panel — glass grid of thumbnails with
/// play-mode toggle. 精简 v1: 单列表视图 (文件夹分组/历史 tab 留待后续).
///
/// 交互契约:
/// - [visible] 驱动滑入/滑出动画, 滑出后经 [onClosed] 由宿主移除 barrier;
/// - 面板下层的全屏 barrier 点击任意处关闭 (点外关闭);
/// - Esc 关闭由宿主键盘层经 [onClosed] 处理, 面板自身不抢焦点.
class PlaylistPanel extends StatelessWidget {
  /// 队列条目视图 (协调器逻辑队列, 断点元数据已合并).
  final ValueListenable<List<PlaylistItem>> entries;

  /// 当前播放条目索引 (-1 = 未播放) — 驱动高亮.
  final ValueListenable<int> currentIndex;

  /// 面板是否可见 — 驱动滑入动画.
  final bool visible;

  /// 点击模式按钮 / 关闭后通知宿主 (宿主管理可见性与 barrier).
  final VoidCallback onClose;

  /// 播放指定索引条目.
  final ValueChanged<int> onPlayEntry;

  /// 移除指定索引条目.
  final ValueChanged<int> onRemoveEntry;

  /// 当前播放模式 — 驱动模式按钮图标.
  final ValueListenable<PlayMode> playMode;

  /// 切换播放模式 (循环: loopAll → loopSingle → shuffle → loopAll).
  final VoidCallback onCyclePlayMode;

  /// 宿主内容区宽度 — 驱动窄窗收缩 (面板不溢出小窗).
  final double availableWidth;

  const PlaylistPanel({
    super.key,
    required this.entries,
    required this.currentIndex,
    required this.visible,
    required this.onClose,
    required this.onPlayEntry,
    required this.onRemoveEntry,
    required this.playMode,
    required this.onCyclePlayMode,
    required this.availableWidth,
  });

  /// 面板几何 — 窄窗 (<500px) 用收缩尺寸, 常规窗用标准尺寸.
  double get _panelWidth => availableWidth < Tokens.compactBreakpoint
      ? Tokens.playlistPanelWidthNarrow
      : Tokens.playlistPanelWidth;

  double get _panelHeight => availableWidth < Tokens.compactBreakpoint
      ? Tokens.playlistPanelHeightNarrow
      : Tokens.playlistPanelHeight;

  @override
  Widget build(BuildContext context) {
    // 常驻动画树: visible 切换只动 slide/opacity, 不卸载子树 (滑出动画完整);
    // 不可见时 IgnorePointer 让点击穿透回视频区.
    return IgnorePointer(
      ignoring: !visible,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.spMd),
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: Tokens.durationNormal),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: Tokens.durationNormal),
              child: GlassContainer(
                tier: GlassTier.normal,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                width: _panelWidth,
                height: _panelHeight,
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题行 — 标题 + 模式切换 + 关闭.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spMd,
            Tokens.spSm,
            Tokens.spSm,
            Tokens.spXs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.playlist,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 模式切换 — 图标随 playMode 变化, 点击循环切换.
              ValueListenableBuilder<PlayMode>(
                valueListenable: playMode,
                builder: (_, mode, _) => IconButton(
                  icon: Icon(playModeIcon(mode), size: 20),
                  color: Tokens.textSecondary,
                  tooltip: playModeLabel(mode, l10n),
                  onPressed: onCyclePlayMode,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Tokens.textSecondary,
                tooltip: l10n.close,
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 条目网格 — 协调器逻辑队列; index 高亮随切曲实时刷新.
        Expanded(
          child: ValueListenableBuilder<List<PlaylistItem>>(
            valueListenable: entries,
            builder: (_, items, _) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    l10n.playlistEmpty,
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                );
              }
              return ValueListenableBuilder<int>(
                valueListenable: currentIndex,
                builder: (_, index, _) => GridView.builder(
                  padding: const EdgeInsets.all(Tokens.spSm),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: Tokens.spXs,
                    crossAxisSpacing: Tokens.spXs,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => PlaylistTile(
                    item: items[i],
                    isCurrent: i == index,
                    onPlay: () => onPlayEntry(i),
                    onRemove: () => onRemoveEntry(i),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
