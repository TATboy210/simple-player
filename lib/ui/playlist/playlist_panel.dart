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
  /// 蔓延动画单一时间轴 — 面板宽度揭示与条目 stagger 同源同步 (无违和关键).
  late final AnimationController _controller;

  /// 面板竖条宽度 — 窄条形态 (v0.0.5 用户要求收窄), 不遮挡视频主体.
  static const _panelWidth = 280.0;

  /// 条目 stagger 交错步长 (时间轴比例) — 前 10 项错开, 其余随末段直进.
  static const _staggerStep = 0.05;

  /// 单条目缓进时长占比 (stagger 之后的窗口).
  static const _staggerSpan = 0.45;

  /// 条目从右向左缓进的初始位移 (px).
  static const _staggerShift = 36.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = widget.visible ? 1.0 : 0.0;
  }

  static const _duration = Duration(milliseconds: 280);

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

  /// 条目在时间轴 t 上的缓进进度 — [Interval] 交错, 收敛到 [0, 1].
  double _staggerProgress(int index, double t) {
    final start = (index * _staggerStep).clamp(0.0, 1.0 - _staggerSpan);
    if (t <= start) return 0;
    if (t >= start + _staggerSpan) return 1;
    return Curves.easeOutCubic.transform((t - start) / _staggerSpan);
  }

  @override
  Widget build(BuildContext context) {
    // 外壳: ClipRect + Align(widthFactor) — 从右向左蔓延揭示.
    // AnimatedBuilder 驱动重建: controller 前进时 widthFactor 跟随,
    // 否则 forward 动画不会触发 build (value 直读无监听).
    // widthFactor=0 时零宽零命中, 关闭后自动让出点击区域.
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: Curves.easeOutCubic.transform(_controller.value),
          child: SizedBox(width: _panelWidth, child: child),
        ),
      ),
      child: _buildShell(context),
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
        const Divider(height: 1),
        // 条目纵列 — 索引高亮随切曲实时刷新; 条目 stagger 与蔓延同步.
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
                  itemBuilder: (_, i) => _staggered(
                    i,
                    PlaylistTile(
                      item: items[i],
                      isCurrent: i == index,
                      onPlay: () => widget.onPlayEntry(i),
                      onResume: () => widget.onResumeEntry(i),
                      onRemove: () => widget.onRemoveEntry(i),
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

  /// 条目缓进包装 — 动画结束后直通(零包装), 滚动懒加载不重播.
  Widget _staggered(int index, Widget child) {
    final progress = _staggerProgress(index, _controller.value);
    if (progress >= 1) return child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final p = _staggerProgress(index, _controller.value);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset((1 - p) * _staggerShift, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
