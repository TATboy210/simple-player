import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/models/playlist_sort.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_confirm_strip.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/glass_blur_layer.dart';
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
  /// 面板竖条宽度 — 窄条形态 (v0.0.5 用户要求收窄), 不遮挡视频主体.
  /// 公开常量: 设置面板中列挂载 (v0.0.7.2) 计算右缘避让量需要它.
  static const double panelWidth = 280.0;

  /// 队列条目视图 (协调器逻辑队列, 断点元数据已合并).
  final ValueListenable<List<PlaylistItem>> entries;

  /// 当前播放条目索引 (-1 = 未播放) — 驱动高亮.
  final ValueListenable<int> currentIndex;

  /// 上次播放条目路径 (v0.0.6.2) — 停止态 (index == -1) 逻辑高亮锚点;
  /// 播放态高亮以 currentIndex 优先, 锚仅作兜底显示.
  final ValueListenable<String?> lastPlayedPath;

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

  /// 批量移除选中索引集合 (v0.0.7) — 确认对话框后调用.
  /// null 时右键菜单"批量删除"入口隐藏 (旧调用方兼容).
  final ValueChanged<Set<int>>? onRemoveEntries;

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

  /// 断点续播总开关 (v0.0.6, 可选) — false 时条目断点进度/续播分区隐藏;
  /// null 恒允许 (测试退路).
  final ValueListenable<bool>? resumeEnabled;

  const PlaylistPanel({
    super.key,
    required this.entries,
    required this.currentIndex,
    required this.lastPlayedPath,
    required this.visible,
    required this.onClose,
    required this.onPlayEntry,
    required this.onResumeEntry,
    required this.onRemoveEntry,
    this.onRemoveEntries,
    required this.playMode,
    required this.onCyclePlayMode,
    required this.sortKey,
    required this.sortAscending,
    required this.onSortSelected,
    this.resumeEnabled,
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

  /// 批量选择模式 (v0.0.7) — 右键菜单"批量删除"进入, 操作条退出.
  bool _batchMode = false;

  /// 批量选中的条目索引集合 — 逻辑队列索引, 条目数变化时自动过滤越界.
  final Set<int> _batchSelected = <int>{};

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
          child: SizedBox(
            width: PlaylistPanel.panelWidth,
            child: _buildShell(context),
          ),
        ),
      ),
    );
  }

  /// 控制栏同款玻璃壳 — ControlBarDecoration.playing 装饰 (深色毛玻璃 +
  /// 蓝色微光边框 + 4-shadow) + 圆角与边框全部对齐控制栏.
  ///
  /// v0.0.8.2 起走 [GlassBlurLayer] 统一门控层：filter 仍是
  /// [GlassTier.normal.blurFilter] 缓存单例（与控制栏同一实例，零分配）；
  /// 新增 opacity 门控 — 淡出至近透明（<1%）即停用 GPU 背景采样
  /// （控制栏同款语义；全隐态 RenderOpacity 本就跳过绘制，门控补上
  /// 的是淡出尾段）。enabled 翻转只换 BackdropFilter.enabled 布尔，
  /// 渲染结构恒定 — 开关动画丝滑的根源不变。
  Widget _buildShell(BuildContext context) {
    return Container(
      decoration: _panelDecoration,
      child: GlassBlurLayer(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
        opacity: _fade,
        child: _buildContent(context),
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
        // 标题行 — 常态: 标题 + 排序 + 模式切换 + 关闭; 批量模式: 操作条.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spMd,
            Tokens.spMd,
            Tokens.spSm,
            Tokens.spSm,
          ),
          child: _batchMode
              ? _buildBatchHeader(l10n)
              : _buildNormalHeader(l10n),
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
              // v0.0.6: 断点开关监听层 — null 恒允许 (测试退路),
              // ValueListenableBuilder 直挂恒真 notifier 的开销省略.
              // v0.0.6.2: 锚点监听层 — 停止态高亮随 lastPlayedPath 刷新.
              final resume = widget.resumeEnabled;
              if (resume == null) {
                return ValueListenableBuilder<int>(
                  valueListenable: widget.currentIndex,
                  builder: (_, index, _) => ValueListenableBuilder<String?>(
                    valueListenable: widget.lastPlayedPath,
                    builder: (_, lastPlayed, _) =>
                        _buildList(items, index, lastPlayed, true),
                  ),
                );
              }
              return ValueListenableBuilder<bool>(
                valueListenable: resume,
                builder: (_, allowed, _) => ValueListenableBuilder<int>(
                  valueListenable: widget.currentIndex,
                  builder: (_, index, _) => ValueListenableBuilder<String?>(
                    valueListenable: widget.lastPlayedPath,
                    builder: (_, lastPlayed, _) =>
                        _buildList(items, index, lastPlayed, allowed),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 常态标题行 — 标题 + 排序 + 模式切换 + 关闭 (v0.0.6: 三按钮统一
  /// GlassButton.iconOnly 方块风格, 向控制栏看齐).
  Widget _buildNormalHeader(AppLocalizations l10n) {
    return Row(
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
    );
  }

  /// 批量模式操作条 (v0.0.7) — 已选计数 + 全选 + 删除 + 取消,
  /// 按钮沿用 GlassButton.iconOnly 方块风格与标题行同框替换.
  Widget _buildBatchHeader(AppLocalizations l10n) {
    final selectedCount = _batchSelected.length;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.batchSelectedCount(selectedCount),
            style: const TextStyle(
              color: Tokens.accent,
              fontSize: Tokens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // 全选/反选 — 图标随全选态切换.
        GlassButton.iconOnly(
          icon: selectedCount > 0 ? Icons.deselect : Icons.select_all,
          tooltip: l10n.selectAll,
          onPressed: () => setState(_toggleSelectAll),
        ),
        // 删除 — 确认对话框后执行 (0 选中时禁用).
        GlassButton.iconOnly(
          icon: Icons.delete_outline,
          tooltip: l10n.batchDeleteConfirmAction,
          onPressed: selectedCount == 0
              ? null
              : () => unawaited(_confirmBatchDelete()),
        ),
        GlassButton.iconOnly(
          icon: Icons.close,
          tooltip: l10n.cancel,
          onPressed: _exitBatchMode,
        ),
      ],
    );
  }

  /// 进入批量选择模式 — [initialIndex] 为右键发起条目, 默认选中 (v0.0.7).
  void _enterBatchMode(int? initialIndex) {
    setState(() {
      _batchMode = true;
      _batchSelected.clear();
      if (initialIndex != null) _batchSelected.add(initialIndex);
    });
  }

  void _exitBatchMode() {
    setState(() {
      _batchMode = false;
      _batchSelected.clear();
    });
  }

  /// 切换单条选中态 — 越界索引自动忽略 (队列外部变化防护).
  void _toggleSelect(int index) {
    setState(() {
      if (!_batchSelected.add(index)) _batchSelected.remove(index);
    });
  }

  /// 全选/反选 — 已全选则清空, 否则选中全部当前条目.
  void _toggleSelectAll() {
    setState(() {
      // 全选判定用 builder 内传入的 items 长度 — 此处经 entries 快照.
      final total = widget.entries.value.length;
      if (_batchSelected.length >= total) {
        _batchSelected.clear();
      } else {
        _batchSelected
          ..clear()
          ..addAll([for (var i = 0; i < total; i++) i]);
      }
    });
  }

  /// 批量删除确认 — 长条玻璃确认条 (正式文案明示"不影响本地磁盘文件"),
  /// 确认后执行移除并退出多选模式 (v0.0.7).
  Future<void> _confirmBatchDelete() async {
    final l10n = AppLocalizations.of(context);
    final count = _batchSelected.length;
    if (count == 0) return;

    final confirmed = await GlassConfirmStrip.show(
      context,
      message: l10n.batchDeleteConfirmBody(count),
      confirmTooltip: l10n.batchDeleteConfirmAction,
    );

    if (!confirmed || !mounted) return;
    final toRemove = Set<int>.of(_batchSelected);
    _exitBatchMode();
    widget.onRemoveEntries?.call(toRemove);
  }

  /// 单条移除确认 (v0.0.7) — 与批量删除共用确认条; 计数恒 1,
  /// 文案语义复用同一正式模板.
  Future<void> _confirmSingleRemove(int index) async {
    final l10n = AppLocalizations.of(context);
    if (index < 0 || index >= widget.entries.value.length) return;

    final confirmed = await GlassConfirmStrip.show(
      context,
      message: l10n.batchDeleteConfirmBody(1),
      confirmTooltip: l10n.batchDeleteConfirmAction,
    );

    if (!confirmed || !mounted) return;
    widget.onRemoveEntry(index);
  }

  /// 条目纵列 — [lastPlayed] 为停止态高亮锚点; [resumeAllowed] 传递断点
  /// UI 门控 (v0.0.6).
  Widget _buildList(
    List<PlaylistItem> items,
    int index,
    String? lastPlayed,
    bool resumeAllowed,
  ) {
    // 批量模式越界防护 — 队列被外部变化 (引擎回流/落盘恢复) 收缩时,
    // 选中索引可能越界; builder 内过滤保证渲染与删除输入恒有效.
    final validSelection = _batchSelected
        .where((i) => i >= 0 && i < items.length)
        .toSet();
    return ScrollbarTheme(
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
          itemBuilder: (_, i) {
            // 状态合成 (v0.0.6.2): 播放中 = accent 蓝; 停止态 (index == -1)
            // 的"上次会话最后播放"条目 = 续播锚点白 (path 匹配). 播放态
            // 锚已被 revision 同步为当前 path, 两状态天然不并存.
            return PlaylistTile(
              item: items[i],
              isCurrent: i == index,
              isResumeAnchor: index < 0 && items[i].path == lastPlayed,
              onPlay: () => widget.onPlayEntry(i),
              onResume: () => widget.onResumeEntry(i),
              // v0.0.7: 单条移除也过确认条 (与批量共用正式文案).
              onRemove: () => unawaited(_confirmSingleRemove(i)),
              selectionMode: _batchMode,
              isSelected: validSelection.contains(i),
              onToggleSelect: () => _toggleSelect(i),
              onStartBatchSelect: widget.onRemoveEntries == null || _batchMode
                  ? null
                  : () => _enterBatchMode(i),
              resumeAllowed: resumeAllowed,
            );
          },
        ),
      ),
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
    final button = buttonContext.findRenderObject() as RenderBox?;
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
