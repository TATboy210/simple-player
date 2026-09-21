import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/services/thumbnail_service.dart';
import '../../kernel/utils/path_utils.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import '../theme/tokens.dart';

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
    this.resumeAllowed = true,
  });

  @override
  State<PlaylistTile> createState() => _PlaylistTileState();
}

/// 缩略图三态（P-Thumb v1.3.2 §26）— loading/ready/failed 驱动占位与重试入口
enum _ThumbPhase { loading, ready, failed }

class _PlaylistTileState extends State<PlaylistTile> {
  ImageProvider? _thumbnail;
  _ThumbPhase _phase = _ThumbPhase.loading;

  /// 生命周期代次 — didUpdateWidget/dispose 递增失效旧异步回写（§26）
  int _loadGeneration = 0;

  /// Image 解码失败标记 — errorBuilder 经 post-frame 回写；
  /// phase 可能是 ready（provider 非 null 但 bytes 损坏），重试入口需可见
  bool _decodeFailed = false;

  /// 鼠标悬停态 — 驱动整卡背景微亮 (v0.0.6.2).
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  /// path 变化触发重载 — P-Thumb v1.3.2 §26.0 强制保留的触发器
  /// （generation 机制的第二个递增来源；实施契约 45）
  @override
  void didUpdateWidget(covariant PlaylistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) _loadThumbnail();
  }

  @override
  void dispose() {
    // dispose 后 generation 失效 + mounted false — 双保险拒绝旧回写（§26.4）
    _loadGeneration++;
    super.dispose();
  }

  /// 异步取缩略图 — 三保险防 path reuse（§26.2）：mounted + generation +
  /// capturedPath。ThumbnailService 内部带 identity/LRU/磁盘缓存与降级；
  /// 失败转入 failed 态（右侧出现重试入口），绝不阻断列表滚动.
  Future<void> _loadThumbnail() async {
    final generation = ++_loadGeneration;
    final path = widget.item.path;

    if (!mounted) return;

    setState(() {
      _thumbnail = null;
      _decodeFailed = false;
      _phase = _ThumbPhase.loading;
    });

    final provider = await ThumbnailService.getThumbnail(path);

    if (!mounted || generation != _loadGeneration || path != widget.item.path) {
      return;
    }

    setState(() {
      _thumbnail = provider;
      _phase = provider == null ? _ThumbPhase.failed : _ThumbPhase.ready;
    });
  }

  /// 用户点击重试 — ThumbnailService.retry 强制绕过内存/磁盘缓存重新
  /// 解帧（§27.4）；成功返回 MemoryImage 即时展示新 bytes.
  Future<void> _retryThumbnail() async {
    final generation = ++_loadGeneration;
    final path = widget.item.path;

    if (!mounted) return;

    setState(() {
      _thumbnail = null;
      _decodeFailed = false;
      _phase = _ThumbPhase.loading;
    });

    final provider = await ThumbnailService.retry(path);

    if (!mounted || generation != _loadGeneration || path != widget.item.path) {
      return;
    }

    setState(() {
      _thumbnail = provider;
      _phase = provider == null ? _ThumbPhase.failed : _ThumbPhase.ready;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 状态色三态 (v0.0.6.2): 播放中 accent 蓝 / 续播锚点白 / 普通无边框.
    // 名称色复用同一高亮色 — 锚点白与 textPrimary 同亮度, 视觉一致.
    final highlightColor = widget.isCurrent
        ? Tokens.accent
        : (widget.isResumeAnchor ? Tokens.playlistAnchorWhite : null);
    final borderColor = highlightColor ?? Colors.transparent;

    // v0.0.5: 去掉条目名称 Tooltip (用户反馈) — 膜层悬停文字已是提示.
    return InkWell(
      onTap: widget.onPlay,
      // InkWell 默认 defer (箭头) — 整卡可点播, 显式给食指与膜按钮一致.
      mouseCursor: SystemMouseCursors.click,
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      // hover 微亮 (v0.0.6.2) — 整卡背景白 tint 渐入渐出, 替代原蓝色
      // 辉光边框 (blue glow 与播放态 accent 蓝语义混淆; 微亮即定位反馈,
      // 不与两种状态高亮争夺视觉层级).
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: Tokens.durationNormal),
          padding: const EdgeInsets.all(Tokens.spXs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            color: _hovered ? Tokens.glowHighlightWhite : Colors.transparent,
            border: Border.all(
              color: borderColor,
              width: highlightColor != null ? 1.5 : 0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图 — 透明塑料膜按钮层覆盖其上 (整个缩略图区域,
              // 膜层 ClipRRect 与缩略图同款圆角 — 用户钦定).
              SizedBox(
                width: _thumbWidth,
                height: _thumbHeight,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildThumbnail()),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _FilmButton(
                                icon: Icons.play_arrow,
                                label: l10n.play,
                                onTap: widget.onPlay,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _FilmButton(
                                icon: Icons.replay,
                                label: l10n.resumePlayback,
                                enabled: _resumeProgress != null,
                                onTap: _resumeProgress == null
                                    ? null
                                    : widget.onResume,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tokens.spSm),
              // 名称 + 上次播放进度 — 缩略图右侧.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称 + 失败重试入口同行 — 重试 24px 热区（§27.2）
                    // 位于缩略图外，绝不覆盖 FilmButton 播放/续播分区.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: highlightColor ?? Tokens.textPrimary,
                              fontSize: Tokens.fontCaption,
                            ),
                          ),
                        ),
                        if (_showRetry) _buildRetryButton(),
                      ],
                    ),
                    if (_resumeProgress != null) ...[
                      const SizedBox(height: Tokens.spXs),
                      // 上次播放进度 — 细进度条 + 断点时间.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        child: LinearProgressIndicator(
                          value: _resumeProgress,
                          minHeight: 3,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Tokens.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.breakpointAt(
                          formatMs(widget.item.positionMs ?? 0),
                        ),
                        style: const TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 缩略图宽度 — 决定条目高度 (16:9 → 72px).
  static const _thumbWidth = 128.0;
  static const _thumbHeight = 72.0;

  /// 解码宽度上限 — 与 ThumbnailSpec 冻结值 320 一致（§14A.2，
  /// 防 高 DPI 把 decoded image 无限制放大）.
  static const _maxDecodeWidth = 320;

  /// 失败重试入口可见性 — provider 失败（phase failed）或解码失败
  /// （decodeFailed）任一即显示（§27.1/§27.3）.
  bool get _showRetry => _phase == _ThumbPhase.failed || _decodeFailed;

  /// 失败重试入口 — 24px 热区 icon-only（refresh 语义自明），
  /// 位于名称行右侧，不改变 Tile 总高度（§27.1）.
  Widget _buildRetryButton() {
    return SizedBox(
      width: Tokens.iconButtonSizeSmall,
      height: Tokens.iconButtonSizeSmall,
      child: IconButton(
        onPressed: _retryThumbnail,
        icon: const Icon(
          Icons.refresh_outlined,
          size: 16,
          color: Tokens.textSecondary,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: Tokens.iconButtonSizeSmall,
          minHeight: Tokens.iconButtonSizeSmall,
        ),
      ),
    );
  }

  /// loading/failed 共用占位 — 电影 icon（§27.1：不为 loading 加独立
  /// spinner 噪音；failed 的重试入口在名称行）.
  Widget _thumbPlaceholder() {
    return const Center(
      child: Icon(Icons.movie_outlined, size: 22, color: Tokens.textSecondary),
    );
  }

  /// 解码失败回写 — errorBuilder 在 build 期间触发，post-frame 再 setState.
  void _scheduleDecodeFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _decodeFailed) return;
      setState(() => _decodeFailed = true);
    });
  }

  /// 16:9 缩略图三态渲染（§27.1）— 占位 → 异步图像; ready 按 Tile 物理
  /// 宽度解码降内存（§14A.2：显示不变，decoded 工作集 ~230→~144 KiB/张）.
  Widget _buildThumbnail() {
    final thumbnail = _thumbnail;
    final isReady = _phase == _ThumbPhase.ready;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 占位底色 — 缩略图加载完成前保持视觉占位.
          const ColoredBox(color: Tokens.bgGlass),
          if (isReady && thumbnail != null)
            Image(
              image: ResizeImage(
                thumbnail,
                // 单轴 width 保持纵横比 — 128 logical × DPR，clamp 128..320
                width: (_thumbWidth * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(_thumbWidth.toInt(), _maxDecodeWidth)
                    .toInt(),
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) {
                // bytes 损坏等解码失败 — 立即占位 + post-frame 揭示重试入口
                _scheduleDecodeFailed();
                return _thumbPlaceholder();
              },
            )
          else
            _thumbPlaceholder(),
        ],
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
}

/// 透明"塑料膜"按钮分区 — 覆盖缩略图的一片区域, 交互三态:
/// 静置完全透明 (缩略图焦点不受损), hover 微亮 (white 6%), 按下变暗
/// (black 12%, pointer-down 即时 — Apple fluid interfaces §1).
///
/// 两段延迟揭示 (用户钦定): hover 1s 后图标渐显 (居中), 再 1s 后功能名
/// 渐进展示 — [ClipRect] 内 `Align(widthFactor)` 由 [TweenAnimationBuilder]
/// 驱动文字展开, 图标被自然推左; 移出立即反向渐退 (计时器作废, 两态同帧
/// 回落, [AnimatedOpacity]/widthFactor 各自渐退).
class _FilmButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// null = 禁用 (如无断点的续播) — 不响应点击, hover 无反馈.
  final VoidCallback? onTap;

  /// 禁用态显式标记 — 与 onTap == null 同源传入, 驱动图标淡化.
  final bool enabled;

  const _FilmButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_FilmButton> createState() => _FilmButtonState();
}

class _FilmButtonState extends State<_FilmButton> {
  bool _hovering = false;
  bool _pressed = false;

  /// 两段延迟揭示状态 — hover 1s 后图标渐显, 再 1s 后文字展开.
  bool _iconShown = false;
  bool _textShown = false;
  Timer? _iconTimer;
  Timer? _textTimer;

  /// 图标显现的 hover 延迟 (用户钦定 0.4s).
  static const _iconDelay = Duration(milliseconds: 400);

  /// 文字展开距图标显现的间隔 (用户钦定再 1s).
  static const _textDelay = Duration(seconds: 1);

  static const _fadeDuration = Duration(
    milliseconds: Tokens.durationControlsFade,
  );

  bool get _enabled => widget.enabled && widget.onTap != null;

  void _onEnter() {
    setState(() => _hovering = true);
    if (!_enabled) return;
    _iconTimer = Timer(_iconDelay, () {
      if (!mounted) return;
      setState(() => _iconShown = true);
      _textTimer = Timer(_textDelay, () {
        if (mounted) setState(() => _textShown = true);
      });
    });
  }

  void _onExit() {
    // 移出立即反向渐退 — 计时器作废, 两态同帧回落 (AnimatedOpacity 与
    // widthFactor 各自渐退), 未触发的延迟揭示不再发生.
    _iconTimer?.cancel();
    _textTimer?.cancel();
    _iconTimer = null;
    _textTimer = null;
    setState(() {
      _hovering = false;
      _pressed = false;
      _iconShown = false;
      _textShown = false;
    });
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100), // 即时反馈 (§1)
          color: _pressed
              ? Colors.black.withValues(alpha: 0.12)
              : _hovering && _enabled
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildContent(),
        ),
      ),
    );
  }

  /// 图标 + 渐显文字 — 图标 hover 1s 后渐显 (居中), 文字再 1s 后
  /// widthFactor 0→1 展开, 图标被推左.
  Widget _buildContent() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标 — hover 1s 后渐显.
          AnimatedOpacity(
            opacity: _iconShown && _enabled ? 1.0 : 0.0,
            duration: _fadeDuration,
            child: Icon(
              widget.icon,
              size: 22,
              color: _enabled ? Tokens.textPrimary : Tokens.textSecondary,
            ),
          ),
          // 渐显文字区 — ClipRect + widthFactor 0→1 (展开推图标左移);
          // 静置宽 0 不占位, 缩略图焦点不受损.
          ClipRect(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _textShown && _enabled ? 1.0 : 0.0),
              duration: _fadeDuration,
              curve: Curves.easeInOut,
              builder: (_, width, child) => Align(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                heightFactor: 1.0,
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
