import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player/workspace_menu_session.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/models/playlist_sort.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_confirm_strip.dart';
import '../shared/osd_service.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/glass_blur_layer.dart';
import '../shared/glass_container.dart' show GlassButton, GlassTier;
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import 'playlist_tile.dart';
import 'pending_playlist_confirmation.dart';
import '../shared/owned_anchored_menu.dart';
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
  final Object _sortOwner = Object();
  final FocusNode _sortFocus = FocusNode(debugLabel: 'playlist-sort-trigger');
  OwnedMenuHandle<PlaylistSortKey>? _sortMenu;

  /// 批量选择模式 (v0.0.7) — 右键菜单"批量删除"进入, 操作条退出.
  bool _batchMode = false;

  /// 批量选中的条目索引集合 — 逻辑队列索引, 条目数变化时自动过滤越界.
  final Set<int> _batchSelected = <int>{};
  PendingPlaylistConfirmation? _confirmation;
  final FocusNode _cancelFocus = FocusNode(
    debugLabel: 'playlist-confirm-cancel',
  );

  /// 确认按钮焦点节点 — tab-trap 回绕落点 (U2): 卡内只有 cancel/confirm
  /// 两个可聚焦节点, [_confirmationTabTrap] 据此把 Tab 落点锚定在两节点
  /// 之间; debugLabel 供焦点断言与日志定位. dispose 成对释放 (见 dispose).
  final FocusNode _confirmFocus = FocusNode(
    debugLabel: 'playlist-confirm-confirm',
  );

  /// Tab/Shift+Tab 焦点陷阱 (U2) — 确认卡是破坏性动作表面, 焦点越卡后
  /// Enter 可能误触卡外播放器控件; 此处抢在 FocusManager 默认 Tab 遍历
  /// (焦点链上溯阶段) 之前返回 handled, 封死越卡路径.
  ///
  /// 两节点回绕下 shift 方向信息退化 — Tab 与 Shift+Tab 都移动到另一
  /// 节点, 故不读 HardwareKeyboard 的 shift 状态.
  KeyEventResult _confirmationTabTrap(KeyEvent event) {
    // 仅确认卡在显时拦截; KeyRepeat 不移动焦点 (避免长按连跳).
    if (_confirmation == null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (_cancelFocus.hasFocus) {
      _confirmFocus.requestFocus();
    } else {
      _cancelFocus.requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// Resolve once and remove only this panel's local confirmation.
  void _finishConfirmation(bool confirmed, {bool rebuild = true}) {
    final pending = _confirmation;
    _confirmation = null;
    pending?.complete(confirmed);
    if (rebuild && mounted) setState(() {});
  }

  /// Early ESC prevents the player's hardware fallback from exiting fullscreen.
  KeyEventResult _confirmationKey(KeyEvent event) {
    if (_confirmation == null ||
        !widget.visible ||
        ModalRoute.of(context)?.isCurrent != true ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    WorkspaceMenuScope.maybeOf(context)?.session.latchEvent(event);
    if (event is KeyDownEvent) _finishConfirmation(false);
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = widget.visible ? 1.0 : 0.0;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    FocusManager.instance.addEarlyKeyEventHandler(_sortKeyEvent);
    FocusManager.instance.addEarlyKeyEventHandler(_confirmationKey);
  }

  @override
  void didUpdateWidget(covariant PlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible || !identical(oldWidget.entries, widget.entries)) {
      _finishConfirmation(false, rebuild: false);
    }
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void deactivate() {
    _finishConfirmation(false, rebuild: false);
    _sortMenu?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_sortKeyEvent);
    FocusManager.instance.removeEarlyKeyEventHandler(_confirmationKey);
    _finishConfirmation(false, rebuild: false);
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    _sortMenu?.cancel();
    _sortFocus.dispose();
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
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            ExcludeFocus(
              excluding: _confirmation != null,
              child: _buildContent(context),
            ),
            if (_confirmation case final pending?) _buildConfirmation(pending),
          ],
        ),
      ),
    );
  }

  /// The hit-test shield is bounded by the existing panel, never the player.
  Widget _buildConfirmation(PendingPlaylistConfirmation pending) =>
      Positioned.fill(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _finishConfirmation(false),
                child: const ColoredBox(color: Tokens.bgGlass),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.spSm),
                child: Center(
                  // U2 封闭焦点域: FocusTraversalGroup 声明遍历边界,
                  // FocusScope.onKeyEvent 执行 Tab/Shift+Tab 回绕拦截
                  // (handled 先于 FocusManager 默认遍历生效).
                  child: FocusScope(
                    onKeyEvent: (node, event) => _confirmationTabTrap(event),
                    child: FocusTraversalGroup(
                      child: GlassConfirmStrip(
                        message: pending.message,
                        cancelLabel: AppLocalizations.of(context).cancel,
                        confirmTooltip: AppLocalizations.of(context)
                            .batchDeleteConfirmAction,
                        cancelFocus: _cancelFocus,
                        confirmFocus: _confirmFocus,
                        onCancel: () => _finishConfirmation(false),
                        onConfirm: () => _finishConfirmation(true),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

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
              fontWeight: Tokens.weightSemiBold,
            ),
          ),
        ),
        // 排序 (v0.0.6) — 弹出排序方式菜单.
        Builder(
          builder: (buttonContext) => GlassButton.iconOnly(
            icon: Icons.sort,
            focusNode: _sortFocus,
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
              fontWeight: Tokens.weightSemiBold,
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
    _finishConfirmation(false, rebuild: false);
    setState(() => _confirmation = pending);
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
        // 滚轮平滑滚动 (v0.0.11 T4): ListView 塌缩为显式 Scrollable+Viewport,
        // Listener 必须位于 viewportBuilder 内层 — SDK PointerSignalResolver
        // "第一注册者胜出" (命中测试自最深叶起派发), 内层注册先于 Scrollable
        // 自带的瞬跳 Listener, wheel 信号竞拍裁给我们. physics 路线不可行:
        // 它只过 shouldAcceptUserOffset 门, 收不到 wheel 事件.
        child: Scrollable(
          controller: _scrollController,
          semanticChildCount: items.length,
          viewportBuilder: (context, position) => Listener(
            onPointerSignal: _onWheelSignal,
            child: Viewport(
              offset: position,
              slivers: [
                SliverPadding(
                  // 底部 padding 让开面板圆角半径 — 滚动条拉到底不与
                  // 圆角相交 (用户反馈); 右侧留白让滚动条不贴边.
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.spXs,
                    Tokens.spSm,
                    8,
                    Tokens.controlBarRadius,
                  ),
                  sliver: SliverList(
                    // 参数对齐 ListView.builder 默认 (addAutomaticKeepAlives/
                    // addRepaintBoundaries/addSemanticIndexes 恒 true) —
                    // 防缩略图 keep-alive/重绘边界行为漂移.
                    delegate: SliverChildBuilderDelegate((context, i) {
                      // 状态合成 (v0.0.6.2): 播放中 = accent 蓝; 停止态
                      // (index == -1) 的"上次会话最后播放"条目 = 续播锚点白
                      // (path 匹配). 播放态锚已被 revision 同步为当前 path,
                      // 两状态天然不并存.
                      return PlaylistTile(
                        item: items[i],
                        isCurrent: i == index,
                        isResumeAnchor:
                            index < 0 && items[i].path == lastPlayed,
                        onPlay: () => widget.onPlayEntry(i),
                        onResume: () => widget.onResumeEntry(i),
                        // v0.0.7: 单条移除也过确认条 (与批量共用正式文案).
                        onRemove: () => unawaited(_confirmSingleRemove(i)),
                        selectionMode: _batchMode,
                        isSelected: validSelection.contains(i),
                        onToggleSelect: () => _toggleSelect(i),
                        onStartBatchSelect:
                            widget.onRemoveEntries == null || _batchMode
                            ? null
                            : () => _enterBatchMode(i),
                        resumeAllowed: resumeAllowed,
                      );
                    }, childCount: items.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 滚轮平滑滚动 (v0.0.11 T4)
  // ============================================================

  /// 滚轮信号入口 — 注册进 PointerSignalResolver 竞拍.
  ///
  /// resolver 规则: 同一 signal 事件只有第一个 register 的回调生效,
  /// 命中测试自最深叶起派发 → 内层 Listener 先注册 → 裁给我们;
  /// Scrollable 自带的瞬跳 handler (flutter#31658 forcePixels) 因此被压制.
  void _onWheelSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _scrollController.position;
    // 首帧空 content dimension 守卫 — 此时 min/maxScrollExtent 尚不可用.
    if (!position.hasContentDimensions) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _handleWheelScroll,
    );
  }

  /// resolver 中标回调 — wheel delta 换 easeOutCubic 滑行动画.
  void _handleWheelScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _glide(event.scrollDelta.dy);
  }

  /// 从当前 pixels 滑向 clamp 目标 — 连发时 animateTo 自动取消前段并
  /// 从当前位置接力重算, 形成连续滑行; 已在边界 (target == pixels)
  /// 时空转不建动画, 不打断在飞的滑行.
  void _glide(double delta) {
    final position = _scrollController.position;
    final target = clampDouble(
      position.pixels + delta,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: Tokens.playlistWheelGlideMs),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ============================================================
  // 排序 (v0.0.6)
  // ============================================================

  /// Observe only the actual trigger: latch before FAD activates or mutates routes.
  KeyEventResult _sortKeyEvent(KeyEvent event) {
    final trigger = _sortFocus.context;
    if (trigger == null ||
        !_sortFocus.hasPrimaryFocus ||
        !widget.visible ||
        ModalRoute.of(trigger)?.isCurrent != true ||
        SecondarySurfaceVisibility.read(trigger)?.value == false ||
        event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      WorkspaceMenuScope.maybeOf(trigger)?.session.latchEvent(event);
    }
    return KeyEventResult.ignored;
  }

  /// 排序方式菜单 — 锚定排序按钮下方, 当前键打勾并显示方向箭头.
  /// 同键再次选择 = 翻转方向 (由协调器裁定); 菜单为瞬态弹出,
  /// 打开时读取的 sortKey/sortAscending 即最新状态.
  Future<void> _showSortMenu(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(context);
    final handle = OwnedAnchoredMenu.open<PlaylistSortKey>(
      buttonContext,
      owner: _sortOwner,
      triggerFocus: _sortFocus,
      entries: [
        for (final key in PlaylistSortKey.values)
          OwnedMenuEntry(
            value: key,
            label: _sortKeyLabel(key, l10n),
            isChecked: key == widget.sortKey,
            icon: key == widget.sortKey
                ? (widget.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                : null,
          ),
      ],
    );
    _sortMenu = handle;
    final action = await handle.result;
    if (!identical(_sortMenu, handle)) return;
    _sortMenu = null;
    if (!mounted ||
        action == null ||
        !widget.visible ||
        !buttonContext.mounted ||
        SecondarySurfaceVisibility.read(buttonContext)?.value == false ||
        ModalRoute.of(buttonContext)?.isCurrent != true) {
      return;
    }
    // Checked keys are still actions: the coordinator alone flips direction.
    widget.onSortSelected(action.value);
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
