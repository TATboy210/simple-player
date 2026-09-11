import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/models/play_mode.dart';
import '../../kernel/models/playlist_item.dart';
import '../../l10n/app_localizations.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/glass_container.dart' show GlassTier;
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import 'playlist_tile.dart';

/// 播放列表面板 — 右侧竖条, 无边框沉浸式蓝色毛玻璃 (v0.0.5 重设计).
///
/// Playlist side panel — right-edge vertical strip with borderless
/// blue-tinted glassmorphism. 避开控制栏区域, 与控制栏同屏共存.
///
/// 动画设计(用户钦定"从右向左蔓延"):
/// - 面板外壳 [ClipRect] + `Align(widthFactor)` — 打开时从右缘向左蔓延揭示,
///   关闭反向收回; [Curves.easeOutCubic] 蔓延缓动;
/// - 条目 [Opacity] + `Transform.translate` — 从右向左缓进显现, 与面板
///   蔓延共用同一 [AnimationController] 时间轴(按索引 [Interval] 交错),
///   滚动懒加载的条目在动画结束后直通(不重播).
class PlaylistPanel extends StatefulWidget {
  /// 队列条目视图 (协调器逻辑队列, 断点元数据已合并).
  final ValueListenable<List<PlaylistItem>> entries;

  /// 当前播放条目索引 (-1 = 未播放) — 驱动高亮.
  final ValueListenable<int> currentIndex;

  /// 面板是否可见 — 驱动蔓延进入/收回动画 (宿主共享 notifier, 全屏同源).
  final bool visible;

  /// 点击关闭按钮后通知宿主 (宿主翻转可见性 notifier).
  final VoidCallback onClose;

  /// 播放指定索引条目.
  final ValueChanged<int> onPlayEntry;

  /// 断点续播指定索引条目 — 播放 + seek 到断点 (v0.0.5 按钮化).
  final ValueChanged<int> onResumeEntry;

  /// 移除指定索引条目.
  final ValueChanged<int> onRemoveEntry;

  /// 当前播放模式 — 驱动模式按钮图标.
  final ValueListenable<PlayMode> playMode;

  /// 切换播放模式 (循环: loopAll → loopSingle → shuffle → loopAll).
  final VoidCallback onCyclePlayMode;

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
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel>
    with SingleTickerProviderStateMixin {
  /// 渐进渐退动画 — 与控制栏同款 (FadeTransition + easeInOut +
  /// durationControlsFade, v0.0.5 用户钦定: 弃蔓延/条目 stagger).
  late final AnimationController _controller;

  late final Animation<double> _fade;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 驱动, dismissed(完全收回)后
    // 让出命中 (与控制栏 _onAnimStatus dismissed 同语义).
    return IgnorePointer(
      ignoring: _controller.status == AnimationStatus.dismissed,
      child: FadeTransition(
        opacity: _fade,
        child: SizedBox(
          width: _panelWidth,
          child: _buildShell(context),
        ),
      ),
    );
  }

  /// 控制栏同款玻璃壳 — ControlBarDecoration.playing 装饰 (深色毛玻璃 +
  /// 蓝色微光边框 + 4-shadow) + 圆角与边框全部对齐控制栏 (v0.0.5 用户钦定:
  /// 弃右侧渐变模糊, 回归控制栏设计语言).
  Widget _buildShell(BuildContext context) {
    return Container(
      decoration: ControlBarDecoration.playing(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
        child: BackdropFilter(
          filter: GlassTier.normal.blurFilter,
          child: _buildContent(context),
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
              // 模式切换 — 图标随 playMode 变化, 点击循环切换.
              ValueListenableBuilder<PlayMode>(
                valueListenable: widget.playMode,
                builder: (_, mode, _) => IconButton(
                  icon: Icon(playModeIcon(mode), size: 20),
                  color: Tokens.textSecondary,
                  tooltip: playModeLabel(mode, l10n),
                  onPressed: widget.onCyclePlayMode,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Tokens.textSecondary,
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
                builder: (_, index, _) => ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: Tokens.spSm,
                    horizontal: Tokens.spXs,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
