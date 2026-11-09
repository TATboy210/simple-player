import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../theme/tokens.dart';
import 'playlist_tile.dart';
import 'playlist_tokens.dart';

/// 条目纵列 — 滚动条 + 显式 Scrollable/Viewport + [PlaylistTile] 列表.
///
/// Entry column. [lastPlayed] 为停止态高亮锚点; [resumeAllowed] 传递断点
/// UI 门控 (v0.0.6). 滚轮平滑滚动 (v0.0.11 T4): ListView 塌缩为显式
/// Scrollable+Viewport, Listener 位于 viewportBuilder 内层 — SDK
/// PointerSignalResolver "第一注册者胜出", 内层注册先于 Scrollable 自带的
/// 瞬跳 Listener, wheel 信号竞拍裁给 [onPointerSignal].
class PlaylistEntryList extends StatelessWidget {
  /// 创建条目列表.
  const PlaylistEntryList({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.lastPlayed,
    required this.resumeAllowed,
    required this.controller,
    required this.onPointerSignal,
    required this.batchMode,
    required this.batchSelected,
    required this.onPlay,
    required this.onResume,
    required this.onRemove,
    required this.onToggleSelect,
    required this.onStartBatchSelect,
  });

  /// 队列条目视图.
  final List<PlaylistItem> items;

  /// 当前播放索引 (-1 = 未播放).
  final int currentIndex;

  /// 上次播放条目路径 — 停止态高亮锚.
  final String? lastPlayed;

  /// 断点续播 UI 门控.
  final bool resumeAllowed;

  /// 滚动控制器 (Scrollbar 与 Scrollable 共用, 归面板所有).
  final ScrollController controller;

  /// 滚轮信号入口 (内层 Listener).
  final ValueChanged<PointerSignalEvent> onPointerSignal;

  /// 是否处于批量选择模式.
  final bool batchMode;

  /// 批量选中索引 (可能含越界项, 渲染前过滤).
  final Set<int> batchSelected;

  /// 播放第 i 条.
  final ValueChanged<int> onPlay;

  /// 断点续播第 i 条.
  final ValueChanged<int> onResume;

  /// 移除第 i 条 (经确认条).
  final ValueChanged<int> onRemove;

  /// 切换第 i 条选中态.
  final ValueChanged<int> onToggleSelect;

  /// 从第 i 条发起批量选择; null 时右键菜单该项隐藏.
  final ValueChanged<int>? onStartBatchSelect;

  @override
  Widget build(BuildContext context) {
    // 批量模式越界防护 — 队列被外部变化 (引擎回流/落盘恢复) 收缩时,
    // 选中索引可能越界; 渲染期过滤保证渲染与删除输入恒有效.
    final validSelection = batchSelected
        .where((i) => i >= 0 && i < items.length)
        .toSet();
    return ScrollbarTheme(
      // 两端内缩一个圆角半径 — thumb 拉到底不再与面板圆角相交
      // (Scrollbar 绘制区域不受 ListView padding 影响,
      // margin 必须经 ScrollbarThemeData 传入).
      data: const ScrollbarThemeData(
        mainAxisMargin: Tokens.controlBarRadius,
        crossAxisMargin: PlaylistTokens.scrollbarCrossMargin,
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: Scrollable(
          controller: controller,
          semanticChildCount: items.length,
          viewportBuilder: (context, position) => Listener(
            onPointerSignal: onPointerSignal,
            child: Viewport(
              offset: position,
              slivers: [
                SliverPadding(
                  // 底部 padding 让开面板圆角半径 — 滚动条拉到底不与
                  // 圆角相交 (用户反馈); 右侧留白让滚动条不贴边.
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.spXs,
                    Tokens.spSm,
                    PlaylistTokens.listRightPadding,
                    Tokens.controlBarRadius,
                  ),
                  sliver: SliverList(
                    // 参数对齐 ListView.builder 默认 (addAutomaticKeepAlives/
                    // addRepaintBoundaries/addSemanticIndexes 恒 true) —
                    // 防缩略图 keep-alive/重绘边界行为漂移.
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _tileAt(i, validSelection),
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 第 [i] 条 tile — 状态合成 (v0.0.6.2): 播放中 = accent 蓝; 停止态
  /// (index == -1) 的"上次会话最后播放"条目 = 续播锚点白 (path 匹配).
  /// 播放态锚已被 revision 同步为当前 path, 两状态天然不并存.
  Widget _tileAt(int i, Set<int> validSelection) {
    final startBatch = onStartBatchSelect;
    return PlaylistTile(
      item: items[i],
      isCurrent: i == currentIndex,
      isResumeAnchor: currentIndex < 0 && items[i].path == lastPlayed,
      onPlay: () => onPlay(i),
      onResume: () => onResume(i),
      // v0.0.7: 单条移除也过确认条 (与批量共用正式文案).
      onRemove: () => onRemove(i),
      selectionMode: batchMode,
      isSelected: validSelection.contains(i),
      onToggleSelect: () => onToggleSelect(i),
      onStartBatchSelect: startBatch == null || batchMode
          ? null
          : () => startBatch(i),
      resumeAllowed: resumeAllowed,
    );
  }
}
