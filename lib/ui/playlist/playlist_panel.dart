import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/models/playlist_sort.dart';
import '../../l10n/app_localizations.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/glass_container.dart' show GlassButton, GlassTier;
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import 'playlist_tile.dart';

/// 播放列表面板 — 右侧竖条, 控制栏同款圆角玻璃 (v0.0.5).
///
/// Playlist side panel — right-edge vertical strip with control-bar-grade
/// rounded glassmorphism. 底部避开控制栏区域, 与控制栏同屏共存.
///
/// 动画: 控制栏同款渐进渐退 — 纯 opacity FadeTransition, 渲染层驱动,
/// 动画期间 widget 树零重建; IgnorePointer 锚定 [visible] — 关闭瞬间
/// 让出命中, 杜绝渐退中"虚空点击".
class PlaylistPanel extends StatefulWidget {
  /// 队列条目视图 (协调器逻辑队列, 断点元数据已合并).
  final ValueListenable<List<PlaylistItem>> entries;

  /// 当前播放条目索引 (-1 = 未播放) — 驱动高亮.
  final ValueListenable<int> currentIndex;

  /// 面板是否可见 — 驱动渐入渐出动画 (宿主共享 notifier, 全屏同源).
  final bool visible;

  /// 点击关闭按钮后通知宿主 (宿主翻转可见性 notifier).
  final VoidCallback onClose;

  /// 播放指定索引条目.
  final ValueChanged<int> onPlayEntry;

  /// 断点续播指定索引条目 — 播放 + seek 到断点.
  final ValueChanged<int> onResumeEntry;

  /// 移除指定索引条目.
  final ValueChanged<int> onRemoveEntry;

  /// 当前播放模式 — 驱动模式按钮图标.
  final ValueListenable<PlayMode> playMode;

  /// 切换播放模式 (循环: loopAll → loopSingle → shuffle → loopAll).
  final VoidCallback onCyclePlayMode;

  /// 当前排序键 — 菜单勾选态 (菜单瞬态弹出, 打开时取值即最新).
  final PlaylistSortKey sortKey;

  /// 当前排序方向 — true = 升序.
  final bool sortAscending;

  /// 选择排序键 (v0.0.6) — 同键再次选择 = 翻转方向, 由协调器裁定.
  final ValueChanged<PlaylistSortKey> onSortSelected;

  const PlaylistPanel({
    super.key,
    required this.entries,
    required this.currentIndex,
    required this.visible,
    required this.onClose,
    required this.onPlayEntry,
    required this.onResumeEntry,
    required this.onRemoveEntry,
    required this.playMode,
    required this.onCyclePlayMode,
    required this.sortKey,
    required this.sortAscending,
    required this.onSortSelected,
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel>
    with SingleTickerProviderStateMixin {
  /// 渐进渐退动画 — 与控制栏同款 (FadeTransition + easeInOut +
  /// durationControlsFade).
  late final AnimationController _controller;

  late final Animation<double> _fade;

  /// 条目列表滚动控制器 — Scrollbar 显式挂载用 (桌面默认滚动条贴边
  /// 拉满高度, 底部与面板圆角相交).
  final ScrollController _scrollController = ScrollController();

  /// 面板竖条宽度 — 窄条形态 (v0.0.5 用户要求收窄), 不遮挡视频主体.
  static const _panelWidth = 280.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = widget.visible ? 1.0 : 0.0;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant PlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 纯渲染层驱动, 动画全程
    // widget 树零重建 (与控制栏完全一致, v0.0.5 方案 A).
    // IgnorePointer 锚定 widget.visible (而非动画状态): 关闭瞬间立即让出
    // 命中, 根治"面板渐退中还能虚空点击条目触发播放"的竞态.
    return IgnorePointer(
      ignoring: !widget.visible,
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _fade,
          child: SizedBox(width: _panelWidth, child: _buildShell(context)),
        ),
      ),
    );
  }

  /// 控制栏同款玻璃壳 — ControlBarDecoration.playing 装饰 (深色毛玻璃 +
  /// 蓝色微光边框 + 4-shadow) + 圆角与边框全部对齐控制栏.
  ///
  /// 方案 A (完全看齐控制栏): 纯 opacity 渐变 — 玻璃恒定全值模糊, 使用
  /// [GlassTier.normal.blurFilter] 的**缓存 filter 单例** (与控制栏同一
  /// 实例, 零分配); 渲染结构恒定, 开关动画期间 widget 树零重建.
  /// BackdropFilter 的模糊层在面板首次挂载时建立, 之后开关动画无任何
  /// 渲染层结构变化 — 丝滑的根源.
  Widget _buildShell(BuildContext context) {
    return Container(
      decoration: _panelDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
        child: BackdropFilter(
          filter: GlassTier.normal.blurFilter,
          child: _buildContent(context),
        ),
      ),
    );
  }

  /// 面板装饰 — 控制栏同款 playing 装饰, 静态缓存.
  static final _panelDecoration = ControlBarDecoration.playing(
    borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
  );

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题行 — 标题 + 排序 + 模式切换 + 关闭 (v0.0.6: 三按钮统一
        // GlassButton.iconOnly 方块风格, 向控制栏看齐).
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spMd,
            Tokens.spMd,
            Tokens.spSm,
            Tokens.spSm,
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
              // 排序 (v0.0.6) — 弹出排序方式菜单.
              Builder(
                builder: (buttonContext) => GlassButton.iconOnly(
                  icon: Icons.sort,
                  tooltip: l10n.sortBy,
                  onPressed: () => unawaited(_showSortMenu(buttonContext)),
                ),
              ),
              // 模式切换 — 图标随 playMode 变化, 点击循环切换.
              ValueListenableBuilder<PlayMode>(
                valueListenable: widget.playMode,
                builder: (_, mode, _) => GlassButton.iconOnly(
                  icon: playModeIcon(mode),
                  tooltip: playModeLabel(mode, l10n),
                  onPressed: widget.onCyclePlayMode,
                ),
              ),
              GlassButton.iconOnly(
                icon: Icons.close,
                tooltip: l10n.close,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        // 无分割线 — 浑然天成 (v0.0.5 用户钦定): 标题行与条目纵列以
        // 呼吸间距自然过渡.
        Expanded(
          child: ValueListenableBuilder<List<PlaylistItem>>(
            valueListenable: widget.entries,
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
                valueListenable: widget.currentIndex,
                builder: (_, index, _) => ScrollbarTheme(
                  // 两端内缩一个圆角半径 — thumb 拉到底不再与面板圆角
                  // 相交 (Scrollbar 绘制区域不受 ListView padding 影响,
                  // margin 必须经 ScrollbarThemeData 传入).
                  data: const ScrollbarThemeData(
                    mainAxisMargin: Tokens.controlBarRadius,
                    crossAxisMargin: 3,
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      // 底部 padding 让开面板圆角半径 — 滚动条拉到底不与
                      // 圆角相交 (用户反馈); 右侧留白让滚动条不贴边.
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.spXs,
                        Tokens.spSm,
                        8,
                        Tokens.controlBarRadius,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => PlaylistTile(
                        item: items[i],
                        isCurrent: i == index,
                        onPlay: () => widget.onPlayEntry(i),
                        onResume: () => widget.onResumeEntry(i),
                        onRemove: () => widget.onRemoveEntry(i),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 排序 (v0.0.6)
  // ============================================================

  /// 排序方式菜单 — 锚定排序按钮下方, 当前键打勾并显示方向箭头.
  /// 同键再次选择 = 翻转方向 (由协调器裁定); 菜单为瞬态弹出,
  /// 打开时读取的 sortKey/sortAscending 即最新状态.
  Future<void> _showSortMenu(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(context);
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    final button =
        buttonContext.findRenderObject() as RenderBox?;
    if (overlay == null || button == null) return;
    final anchor = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    final action = await showMenu<PlaylistSortKey>(
      context: buttonContext,
      position: RelativeRect.fromRect(
        anchor & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final key in PlaylistSortKey.values)
          PopupMenuItem<PlaylistSortKey>(
            value: key,
            child: Row(
              children: [
                // 勾选标记占位 — 未选项对齐.
                SizedBox(
                  width: 20,
                  child: key == widget.sortKey
                      ? const Icon(Icons.check, size: 16, color: Tokens.accent)
                      : null,
                ),
                Expanded(child: Text(_sortKeyLabel(key, l10n))),
                if (key == widget.sortKey)
                  Icon(
                    widget.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: Tokens.textSecondary,
                  ),
              ],
            ),
          ),
      ],
    );
    if (action == null) return;
    widget.onSortSelected(action);
  }

  /// 排序键 → 菜单文案.
  static String _sortKeyLabel(PlaylistSortKey key, AppLocalizations l10n) =>
      switch (key) {
        PlaylistSortKey.addedOrder => l10n.sortByAddedOrder,
        PlaylistSortKey.name => l10n.sortByName,
        PlaylistSortKey.lastPlayed => l10n.sortByLastPlayed,
        PlaylistSortKey.duration => l10n.sortByDuration,
      };
}
