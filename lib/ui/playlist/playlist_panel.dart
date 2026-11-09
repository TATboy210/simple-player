import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/models/playlist_sort.dart';
import '../../l10n/app_localizations.dart';
import '../shared/osd_service.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/glass_blur_layer.dart';
import '../theme/tokens.dart';
import 'pending_playlist_confirmation.dart';
import 'playlist_confirmation_controller.dart';
import 'playlist_confirmation_overlay.dart';
import 'playlist_entry_list.dart';
import 'playlist_panel_headers.dart';
import 'playlist_sort_menu.dart';
import 'playlist_wheel_glide.dart';
import '../shared/secondary_surface_visibility.dart';

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
  ///
  /// 单一事实来源: Tokens.workspaceTaskMinWidth (工作区右列预留宽, 即
  /// panel_workspace_layout.calculate 的右列预留上界) — 编译期常量到常量,
  /// 保证 854×480 最小窗口下播放列表与右列槽位精确对齐, 任一侧改动不再分叉.
  /// 公开常量: 设置面板中列挂载 (v0.0.7.2) 计算右缘避让量需要它,
  /// 测试 (settings_panel_stack_test) 亦经由它取值.
  static const double panelWidth = Tokens.workspaceTaskMinWidth;

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

  /// seek 拖动挂起信号 (v0.0.8.2, 可选) — true 时玻璃模糊短暂停用,
  /// 松手恢复. null = 无挂起源 (恒不挂起).
  final ValueListenable<bool>? scrubbing;

  /// 窗口 resize 信号 (可选) — true 时玻璃模糊挂起, 结束恢复. null = 不挂起.
  final ValueListenable<bool>? resizing;

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
    this.scrubbing,
    this.resizing,
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

  /// 滚轮平滑滚动 (v0.0.11 T4) — 持有列表滚动控制器 (Scrollbar 显式挂载用,
  /// 桌面默认滚动条贴边拉满高度, 底部与面板圆角相交).
  final PlaylistWheelGlide _wheel = PlaylistWheelGlide();

  /// 排序菜单控制器 (焦点 + 锚定菜单 + early key latch).
  late final PlaylistSortMenu _sortMenu = PlaylistSortMenu(
    isVisible: () => widget.visible,
    isMounted: () => mounted,
  );

  /// 列表层合并监听源 — 断点开关 (可选) + 当前索引 + 锚点路径, 一次读取
  /// 取代原三层嵌套 ValueListenableBuilder. 仅在底层 notifier 身份变化时重建.
  late Listenable _listSignals = _mergeListSignals();

  /// 批量选择模式 (v0.0.7) — 右键菜单"批量删除"进入, 操作条退出.
  bool _batchMode = false;

  /// 批量选中的条目索引集合 — 逻辑队列索引, 条目数变化时自动过滤越界.
  final Set<int> _batchSelected = <int>{};

  /// 确认流控制器 (待确认快照 + 焦点节点 + Tab 陷阱 + 早期 ESC).
  late final PlaylistConfirmationController _confirm =
      PlaylistConfirmationController(onChanged: _rebuild);

  /// 确认流状态翻转 → 重建 (守卫 mounted, dispose 后的迟到回调安全).
  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// 合并列表层监听源 — resume 为 null 时不参与 (测试退路恒允许).
  Listenable _mergeListSignals() => Listenable.merge([
    ?widget.resumeEnabled,
    widget.currentIndex,
    widget.lastPlayedPath,
  ]);

  /// 早期 ESC — 交给确认流控制器.
  KeyEventResult _confirmationKey(KeyEvent event) =>
      _confirm.onEarlyKey(event, visible: widget.visible, context: context);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = widget.visible ? 1.0 : 0.0;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    FocusManager.instance.addEarlyKeyEventHandler(_sortMenu.onEarlyKey);
    FocusManager.instance.addEarlyKeyEventHandler(_confirmationKey);
  }

  @override
  void didUpdateWidget(covariant PlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible || !identical(oldWidget.entries, widget.entries)) {
      _confirm.finish(false, rebuild: false);
    }
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
    // 底层 notifier 身份变化 (宿主换源) 才重建合并源, 常态零分配.
    if (!identical(oldWidget.resumeEnabled, widget.resumeEnabled) ||
        !identical(oldWidget.currentIndex, widget.currentIndex) ||
        !identical(oldWidget.lastPlayedPath, widget.lastPlayedPath)) {
      _listSignals = _mergeListSignals();
    }
  }

  @override
  void deactivate() {
    _confirm.finish(false, rebuild: false);
    _sortMenu.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_sortMenu.onEarlyKey);
    FocusManager.instance.removeEarlyKeyEventHandler(_confirmationKey);
    _confirm.dispose();
    _sortMenu.dispose();
    _wheel.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 纯渲染层驱动, 动画全程
    // widget 树零重建 (与控制栏完全一致, v0.0.5 方案 A).
    // IgnorePointer 锚定 widget.visible (而非动画状态): 关闭瞬间立即让出
    // 命中, 根治"面板渐退中还能虚空点击条目触发播放"的竞态.
    // ExcludeFocus 与 IgnorePointer 并列 (v0.0.12 U1, 对照
    // settings_panel.dart:422 同款写法): 面板常驻挂载, 关闭态若只挡指针
    // 不挡焦点, Tab 遍历仍可落入不可见的 tile 触发器/排序/模式/关闭按钮,
    // Space/Enter 产生"幽灵动作"(播放条目/切播放模式/关面板 — 均为持久
    // 状态副作用). excluding 只随 visible 翻转 — 打开态焦点行为零变化.
    return SecondarySurfaceOwner(
      visible: widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: IgnorePointer(
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
        suspend: widget.scrubbing,
        resizing: widget.resizing,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            ExcludeFocus(
              excluding: _confirm.pending != null,
              child: _buildContent(context),
            ),
            if (_confirm.pending case final pending?)
              PlaylistConfirmationOverlay(
                pending: pending,
                cancelFocus: _confirm.cancelFocus,
                confirmFocus: _confirm.confirmFocus,
                onFinish: _confirm.finish,
                onKeyEvent: _confirm.tabTrap,
              ),
          ],
        ),
      ),
    );
  }

  /// 面板装饰 — 控制栏同款 playing 装饰, 静态缓存.
  static final _panelDecoration = ControlBarDecoration.playing(
    borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
  );

  /// 标题行 + 条目区. 标题行常态: 标题 + 排序 + 模式切换 + 关闭;
  /// 批量模式: 操作条. 无分割线 — 浑然天成 (v0.0.5 用户钦定): 标题行与
  /// 条目纵列以呼吸间距自然过渡.
  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spMd,
            Tokens.spMd,
            Tokens.spSm,
            Tokens.spSm,
          ),
          child: _batchMode ? _buildBatchHeader() : _buildNormalHeader(),
        ),
        Expanded(
          child: ValueListenableBuilder<List<PlaylistItem>>(
            valueListenable: widget.entries,
            builder: (_, items, _) =>
                items.isEmpty ? _buildEmpty(l10n) : _buildListLayer(items),
          ),
        ),
      ],
    );
  }

  /// 空队列占位文案.
  Widget _buildEmpty(AppLocalizations l10n) {
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

  /// 列表监听层 — 断点开关 (v0.0.6, null 恒允许) + 当前索引 + 锚点路径
  /// (v0.0.6.2) 经 [_listSignals] 合并为单层, 一次读取三个值.
  Widget _buildListLayer(List<PlaylistItem> items) {
    return ListenableBuilder(
      listenable: _listSignals,
      builder: (_, _) => _buildList(
        items,
        widget.currentIndex.value,
        widget.lastPlayedPath.value,
        widget.resumeEnabled?.value ?? true,
      ),
    );
  }

  /// 常态标题行 (排序/模式/关闭).
  Widget _buildNormalHeader() {
    return PlaylistNormalHeader(
      sortFocus: _sortMenu.focusNode,
      onSortPressed: (buttonContext) => _sortMenu.open(
        buttonContext,
        sortKey: widget.sortKey,
        ascending: widget.sortAscending,
        onSelected: widget.onSortSelected,
      ),
      playMode: widget.playMode,
      onCyclePlayMode: widget.onCyclePlayMode,
      onClose: widget.onClose,
    );
  }

  /// 批量模式操作条 (v0.0.7).
  Widget _buildBatchHeader() {
    return PlaylistBatchHeader(
      selectedCount: _batchSelected.length,
      onToggleSelectAll: () => setState(_toggleSelectAll),
      onDelete: () => unawaited(_confirmBatchDelete()),
      onCancel: _exitBatchMode,
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
    // 全选判定经 entries 快照 (setState 回调内同步执行).
    final total = widget.entries.value.length;
    if (_batchSelected.length >= total) {
      _batchSelected.clear();
    } else {
      _batchSelected
        ..clear()
        ..addAll([for (var i = 0; i < total; i++) i]);
    }
  }

  /// Freeze target identities and wording before yielding to the user's choice.
  Future<PendingPlaylistConfirmation?> _confirmTargets(Set<int> indices) async {
    if (!widget.visible || !mounted) return null;
    // message 改为回调形态 — 文案计数由冻结后的 targetCount 求值 (H3:
    // 重复条目不再被丢弃, 计数与实际可删目标一致)。
    final pending = PendingPlaylistConfirmation(
      message: (count) =>
          AppLocalizations.of(context).batchDeleteConfirmBody(count),
      entries: widget.entries.value,
      indices: indices,
    );
    if (pending.isEmpty) return null;
    _confirm.show(pending);
    final confirmed = await pending.result;
    if (!confirmed || !mounted || !widget.visible) return null;
    return pending;
  }

  /// 批量移除仅使用打开时的快照；不影响本地磁盘文件。
  Future<void> _confirmBatchDelete() async {
    if (_batchSelected.isEmpty) return;
    final pending = await _confirmTargets(Set.of(_batchSelected));
    if (!mounted || !widget.visible || pending == null) return;
    _exitBatchMode();
    // Resolve after all asynchronous waits, immediately before the callback.
    final toRemove = pending.resolve(widget.entries.value);
    if (toRemove.isNotEmpty) {
      widget.onRemoveEntries?.call(toRemove);
    } else {
      // 确认后目标全落空 (队列被外部清空/目标全消失) — 不再静默无响应,
      // 以固定文案 OSD 轻提示告知用户 (U1)。
      _showEntriesGoneHint();
    }
  }

  /// Single removal resolves the frozen path against the current queue.
  Future<void> _confirmSingleRemove(int index) async {
    final pending = await _confirmTargets({index});
    if (!mounted || !widget.visible || pending == null) return;
    final toRemove = pending.resolve(widget.entries.value);
    if (toRemove.isNotEmpty) {
      widget.onRemoveEntry(toRemove.single);
    } else {
      // 单条路径同一缺陷形态 — 目标落空同样给 OSD 轻提示 (U1)。
      _showEntriesGoneHint();
    }
  }

  /// 确认后目标全落空的轻提示 — 固定本地化文案, 绝不内插条目路径
  /// (视口 OSD 气泡不暴露文件名); status 级 (rank 0) 永不顶掉在显的
  /// warning/failure OSD, 仅填充空位/低优先级槽位。
  void _showEntriesGoneHint() {
    OsdService.I.show(AppLocalizations.of(context).playlistEntriesGone);
  }

  /// 条目纵列 — [lastPlayed] 为停止态高亮锚点; [resumeAllowed] 传递断点
  /// UI 门控 (v0.0.6).
  Widget _buildList(
    List<PlaylistItem> items,
    int index,
    String? lastPlayed,
    bool resumeAllowed,
  ) {
    return PlaylistEntryList(
      items: items,
      currentIndex: index,
      lastPlayed: lastPlayed,
      resumeAllowed: resumeAllowed,
      controller: _wheel.controller,
      onPointerSignal: _wheel.onSignal,
      batchMode: _batchMode,
      batchSelected: _batchSelected,
      onPlay: widget.onPlayEntry,
      onResume: widget.onResumeEntry,
      onRemove: (i) => unawaited(_confirmSingleRemove(i)),
      onToggleSelect: _toggleSelect,
      onStartBatchSelect: widget.onRemoveEntries == null
          ? null
          : _enterBatchMode,
    );
  }
}
