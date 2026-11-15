import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../theme/tokens.dart';
import 'playlist_entry_menu.dart';
import 'playlist_thumb_box.dart';
import 'playlist_thumbnail.dart';
import 'playlist_tile_info.dart';
import 'playlist_tokens.dart';

/// 播放列表条目卡 — 缩略图 + 透明"塑料膜"按钮层 + 右侧名称/断点信息.
///
/// Playlist entry card — thumbnail with a transparent plastic-film button
/// layer covering it (播放 3/5 上 + 断点续播 2/5 下, 用户钦定交互):
/// - 按钮本身**不可见** — 只有 hover 时该分区微亮 (white 6%), 按下变暗
///   (black 12%, pointer-down 即时反馈); 亮度绝不喧宾夺主抢缩略图焦点.
/// - hover 按钮分区: 图标左移 + 功能名 (播放/断点续播) 渐进展示 —
///   与面板 fade 同节奏 (durationControlsFade), 移出反向渐退.
/// - 无 Tooltip — 文字本身就是提示 (用户钦定).
/// - 名称与上次播放进度 (细进度条 + 断点时间) 在缩略图右侧.
///
/// 缩略图经 [ThumbnailService] 缓存异步加载 (加载中显示占位, 绝不阻断列表滚动).
class PlaylistTile extends StatefulWidget {
  final PlaylistItem item;

  /// 是否为当前正在播放的条目 — accent 蓝高亮 (边框 + 名称).
  final bool isCurrent;

  /// 是否为续播锚点 (v0.0.6.2) — 停止态"上次会话最后播放"的条目,
  /// 白色高亮与播放中的 accent 蓝区分状态语义. 播放态下恒 false
  /// (面板合成层保证不双高亮).
  final bool isResumeAnchor;

  /// 播放该条目 (点卡片/播放分区).
  final VoidCallback onPlay;

  /// 断点续播 — 播放并 seek 到 [PlaylistItem.positionMs].
  final VoidCallback onResume;

  /// 右键菜单"移除"动作.
  final VoidCallback onRemove;

  /// 批量选择模式 (v0.0.7) — true 时整卡点击 = 切换选中态,
  /// 播放/续播膜分区禁用, 右上角显示勾选圆标.
  final bool selectionMode;

  /// 批量选择模式下的选中态 (配合 [selectionMode]).
  final bool isSelected;

  /// 批量选择模式下的点击回调 — 切换选中态.
  final VoidCallback? onToggleSelect;

  /// 右键菜单"批量删除"回调 — 面板进入多选模式并选中本条目 (v0.0.7).
  /// null 时菜单项隐藏.
  final VoidCallback? onStartBatchSelect;

  /// 断点续播 UI 总开关 (v0.0.6, 默认 true) — false 时续播分区禁用 +
  /// 断点进度条不显示 (设置"记住播放位置"关闭).
  final bool resumeAllowed;

  const PlaylistTile({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.isResumeAnchor,
    required this.onPlay,
    required this.onResume,
    required this.onRemove,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onStartBatchSelect,
    this.resumeAllowed = true,
  });

  @override
  State<PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<PlaylistTile> {
  ImageProvider? _thumbnail;
  PlaylistThumbPhase _phase = PlaylistThumbPhase.loading;

  /// 生命周期代次 — didUpdateWidget/dispose 递增失效旧异步回写（§26）
  int _loadGeneration = 0;

  /// Image 解码失败标记 — errorBuilder 经 post-frame 回写；
  /// phase 可能是 ready（provider 非 null 但 bytes 损坏），重试入口需可见
  bool _decodeFailed = false;

  /// 鼠标悬停态 — 驱动整卡背景微亮 (v0.0.6.2).
  bool _hovered = false;

  /// 右键菜单控制器 (句柄 + 触发器焦点).
  final PlaylistEntryMenu _menu = PlaylistEntryMenu();

  @override
  void initState() {
    super.initState();
    unawaited(_load(ThumbnailService.getThumbnail));
  }

  /// path 变化触发重载 — P-Thumb v1.3.2 §26.0 强制保留的触发器
  /// （generation 机制的第二个递增来源；实施契约 45）
  @override
  void didUpdateWidget(covariant PlaylistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _menu.cancel();
      unawaited(_load(ThumbnailService.getThumbnail));
    }
  }

  @override
  void deactivate() {
    _menu.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    // dispose 后 generation 失效 + mounted false — 双保险拒绝旧回写（§26.4）
    _loadGeneration++;
    _menu.dispose();
    super.dispose();
  }

  /// 异步取缩略图 — 三保险防 path reuse（§26.2）：mounted + generation +
  /// capturedPath。[fetch] 为 ThumbnailService.getThumbnail (常规加载) 或
  /// retry (绕过缓存强制重新解帧, §27.4)；失败转入 failed 态（右侧出现
  /// 重试入口），绝不阻断列表滚动.
  Future<void> _load(Future<ImageProvider?> Function(String path) fetch) async {
    final generation = ++_loadGeneration;
    final path = widget.item.path;

    if (!mounted) return;

    setState(() {
      _thumbnail = null;
      _decodeFailed = false;
      _phase = PlaylistThumbPhase.loading;
    });

    final provider = await fetch(path);

    if (!mounted || generation != _loadGeneration || path != widget.item.path) {
      return;
    }

    setState(() {
      _thumbnail = provider;
      _phase = provider == null
          ? PlaylistThumbPhase.failed
          : PlaylistThumbPhase.ready;
    });
  }

  /// 断点进度 (0-1) — 无时长/未播放/总开关关闭时续播分区禁用/进度区不显示.
  double? get _resumeProgress {
    if (!widget.resumeAllowed) return null;
    final position = widget.item.positionMs ?? 0;
    final duration = widget.item.durationMs ?? 0;
    if (duration <= 0 || position <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  /// 失败重试入口可见性 — provider 失败（phase failed）或解码失败
  /// （decodeFailed）任一即显示（§27.1/§27.3）.
  bool get _showRetry => _phase == PlaylistThumbPhase.failed || _decodeFailed;

  /// 解码失败回写 — errorBuilder 在 build 期间触发，post-frame 再 setState.
  void _scheduleDecodeFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _decodeFailed) return;
      setState(() => _decodeFailed = true);
    });
  }

  /// 状态高亮色 — 播放中 accent 蓝 / 续播锚点白 / 普通 null.
  Color? get _highlightColor {
    if (widget.isCurrent) return Tokens.accent;
    return widget.isResumeAnchor ? Tokens.playlistAnchorWhite : null;
  }

  /// 边框色三态 (v0.0.6.2) + v0.0.7 批量选中 = danger 红 (用户钦定,
  /// 与播放蓝区分语义).
  Color get _borderColor => widget.isSelected
      ? Tokens.danger
      : (_highlightColor ?? Colors.transparent);

  @override
  Widget build(BuildContext context) {
    // v0.0.5: 去掉条目名称 Tooltip (用户反馈) — 膜层悬停文字已是提示.
    return InkWell(
      focusNode: _menu.trigger,
      // v0.0.7: 批量选择模式下整卡点击 = 切换选中 (播放/续播让位).
      onTap: widget.selectionMode ? widget.onToggleSelect : widget.onPlay,
      // InkWell 默认 defer (箭头) — 整卡可点播, 显式给食指与膜按钮一致.
      mouseCursor: SystemMouseCursors.click,
      onSecondaryTapUp: (details) =>
          unawaited(_showContextMenu(context, details.globalPosition)),
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      // hover 微亮 (v0.0.6.2) — 整卡背景白 tint 渐入渐出, 替代原蓝色
      // 辉光边框 (blue glow 与播放态 accent 蓝语义混淆).
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: Tokens.durationNormal),
          padding: const EdgeInsets.all(Tokens.spXs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            color: _hovered ? Tokens.glowHighlightWhite : Colors.transparent,
            // 边框**恒定占位** — 宽度 0↔1.5 切换会让条目内容区随高亮跳变
            // (用户钦定: 选中前后条目尺寸不变); 透明↔有色仅过渡颜色.
            border: Border.all(
              color: _borderColor,
              width: PlaylistTokens.tileBorderWidth,
            ),
          ),
          child: _buildRow(),
        ),
      ),
    );
  }

  /// 缩略图盒 + 右侧信息列.
  Widget _buildRow() {
    final progress = _resumeProgress;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaylistThumbBox(
          thumbnail: PlaylistThumbnail(
            thumbnail: _thumbnail,
            phase: _phase,
            onDecodeFailed: _scheduleDecodeFailed,
          ),
          selectionMode: widget.selectionMode,
          isSelected: widget.isSelected,
          canResume: progress != null,
          onPlay: widget.onPlay,
          onResume: widget.onResume,
        ),
        const SizedBox(width: Tokens.spSm),
        // 名称 + 上次播放进度 — 缩略图右侧.
        Expanded(
          child: PlaylistTileInfo(
            name: widget.item.name,
            nameColor: _highlightColor ?? Tokens.textPrimary,
            showRetry: _showRetry,
            // async 回调包 sync wrapper — VoidCallback 期望同步签名；
            // unawaited 显式弃 Future.
            onRetry: () => unawaited(_load(ThumbnailService.retry)),
            resumeProgress: progress,
            positionMs: widget.item.positionMs ?? 0,
          ),
        ),
      ],
    );
  }

  /// 右键菜单 — 动作只作用于发起时捕获的条目路径.
  Future<void> _showContextMenu(BuildContext context, Offset position) {
    final path = widget.item.path;
    return _menu.open(
      context,
      position,
      path: path,
      currentPath: () => widget.item.path,
      isMounted: () => mounted,
      canBatchDelete: widget.onStartBatchSelect != null,
      onAction: (action) => _dispatch(action, path),
    );
  }

  /// 执行菜单动作 — playback switch 不使菜单失效, 故 locate 用捕获路径.
  void _dispatch(PlaylistEntryAction action, String path) {
    switch (action) {
      case PlaylistEntryAction.play:
        widget.onPlay();
      case PlaylistEntryAction.locate:
        PlaylistEntryMenu.locate(path);
      case PlaylistEntryAction.remove:
        widget.onRemove();
      case PlaylistEntryAction.batchDelete:
        widget.onStartBatchSelect?.call();
    }
  }
}
