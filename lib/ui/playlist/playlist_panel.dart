import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import 'folder_tab.dart';
import 'history_tab.dart';

/// 沉浸式浮窗播放列表 — 浮在控制栏上方，毛玻璃背景，水平缩略图
///
/// 结构：
/// - 上 1/5: tab 切换（文件夹 / 历史）
/// - 下 4/5: 水平缩略图列表
///
/// 交互：
/// - 点击按钮切换显示/隐藏（由父组件控制 [visible]）
/// - 点击外部区域关闭
/// - Escape 关闭
class PlaylistPanel extends StatefulWidget {
  final Playlist playlist;
  final bool visible;
  final VoidCallback onClose;
  final void Function(int index) onSelectIndex;
  final void Function(int index) onRemoveIndex;
  final void Function(String path)? onShowProperties;
  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;
  final VoidCallback? onClearHistory;

  /// 窗口 resize 信号 — true 时跳过 BackdropFilter 避免 GPU readback 卡顿
  final ValueListenable<bool>? resizing;

  /// 可用宽度 — 父组件 LayoutBuilder 提供，用于响应式布局
  final double? availableWidth;

  const PlaylistPanel({
    super.key,
    required this.playlist,
    required this.visible,
    required this.onClose,
    required this.onSelectIndex,
    required this.onRemoveIndex,
    this.onShowProperties,
    this.onFolderScanned,
    this.onClearHistory,
    this.resizing,
    this.availableWidth,
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  final _focusNode = FocusNode();
  final _selectedTab = ValueNotifier<int>(0); // 0=文件夹, 1=历史

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: Tokens.durationSlide),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    if (widget.visible) {
      _anim.forward();
      _requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant PlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _anim.forward();
        _requestFocus();
      } else {
        _anim.reverse();
        _focusNode.unfocus();
      }
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _selectedTab.dispose();
    _anim.dispose();
    super.dispose();
  }

  Widget _buildBackdrop() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLarge),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: BackdropFilter(
          // 使用 GlassTier 缓存的 ImageFilter，避免每帧创建新实例（D-10/D-11）
          filter: GlassTier.thick.blurFilter,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static const _panelWidth = Tokens.playlistPanelWidth;
  static const _panelHeight = Tokens.playlistPanelHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 全屏透明层 — 点击外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onClose,
            child: const SizedBox.expand(),
          ),
        ),
        // 浮窗面板
        Positioned(
          right: Tokens.controlBarMarginH,
          bottom:
              Tokens.controlBarMarginBottom +
              Tokens.controlBarHeight +
              Tokens.spLg,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildPanel(_panelWidth, _panelHeight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(double width, double height) {
    return Focus(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {}, // 拦截点击，不穿透到外部关闭层
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // 背景层：毛玻璃模糊（缓存固定 filter，opacity 淡入避免帧分配）
              // resize 期间跳过 BackdropFilter — 避免 GPU readback 卡顿
              Positioned.fill(
                child: widget.resizing != null
                    ? AnimatedBuilder(
                        animation: widget.resizing!,
                        builder: (_, __) {
                          if (widget.resizing!.value) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(
                                Tokens.radiusLarge,
                              ),
                              child: Container(color: Tokens.bgGlass),
                            );
                          }
                          return _buildBackdrop();
                        },
                      )
                    : _buildBackdrop(),
              ),
              // 内容层：滚动不触发 BackdropFilter 重绘
              RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    color: Tokens.bgGlass,
                    borderRadius: BorderRadius.circular(Tokens.radiusLarge),
                    border: Border.all(color: Tokens.borderHighlight, width: 1),
                  ),
                  child: AnimatedBuilder(
                    animation: _selectedTab,
                    builder: (context, _) => Column(
                      children: [
                        // tab 切换
                        SizedBox(height: 36, child: _buildTabBar()),
                        // 光条分隔线
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: Tokens.spMd,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Tokens.borderHighlight,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // 内容
                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spXs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TabChip(
            icon: Icons.folder,
            label: l10n.folderTab,
            selected: _selectedTab.value == 0,
            onTap: () => _selectedTab.value = 0,
          ),
          const SizedBox(width: Tokens.spLg),
          _TabChip(
            icon: Icons.history,
            label: l10n.historyTab,
            selected: _selectedTab.value == 1,
            onTap: () => _selectedTab.value = 1,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final items = widget.playlist.items;
    final currentIndex = widget.playlist.currentIndex;

    if (_selectedTab.value == 0) {
      return FolderTab(
        items: items,
        currentIndex: currentIndex,
        onSelectIndex: widget.onSelectIndex,
        onRemoveIndex: widget.onRemoveIndex,
        onShowProperties: widget.onShowProperties,
        onFolderScanned: widget.onFolderScanned,
      );
    }
    return HistoryTab(
      items: items,
      currentIndex: currentIndex,
      onSelectIndex: widget.onSelectIndex,
      onRemoveIndex: widget.onRemoveIndex,
      onShowProperties: widget.onShowProperties,
      onClearHistory: widget.onClearHistory,
    );
  }
}

/// Tab 芯片 — 图标 + 文字，选中时 accent 高亮
class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spSm,
            vertical: Tokens.spXs,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            border: selected
                ? Border.all(color: Tokens.borderHighlight, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Tokens.accent : Tokens.textDisabled,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Tokens.accent : Tokens.textDisabled,
                  fontSize: Tokens.fontCaption,
                  fontWeight: selected
                      ? Tokens.weightSemiBold
                      : Tokens.weightRegular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
