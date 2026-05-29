import 'package:flutter/material.dart';

import '../../kernel/bridge/window_service.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度
///
/// 设计决策 (D-11 ~ D-18, D-23, D-27):
/// - 平面风格按钮，非毛玻璃 (D-11)
/// - 双击切换最大化/还原 (D-12)
/// - 独立于 ControlsOverlay (D-18)
/// - 始终可见，无自动隐藏 (D-14)
/// - 透明背景，hover 时半透明 (D-15)
/// - 全屏时隐藏 (D-17)
/// - 仅显示应用名称 (D-27)
class CustomTitleBar extends StatelessWidget {
  final WindowService windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: windowService.isFullscreen,
      builder: (context, isFullscreen, _) {
        if (isFullscreen) return const SizedBox.shrink();
        return _TitleBarContent(windowService: windowService);
      },
    );
  }
}

class _TitleBarContent extends StatefulWidget {
  final WindowService windowService;

  const _TitleBarContent({required this.windowService});

  @override
  State<_TitleBarContent> createState() => _TitleBarContentState();
}

class _TitleBarContentState extends State<_TitleBarContent> {
  final _hovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  void _toggleMaximize() {
    if (widget.windowService.isMaximized.value) {
      widget.windowService.restore();
    } else {
      widget.windowService.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => widget.windowService.startDragging(),
        onDoubleTap: _toggleMaximize,
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, hovered, _) {
            return Container(
              height: Tokens.titleBarHeight,
              color: hovered ? Tokens.titleBarBg : Colors.transparent,
              child: Row(
                children: [
                  // 应用名称 (D-27)
                  const Padding(
                    padding: EdgeInsets.only(left: Tokens.spMd),
                    child: Text(
                      'Simple Player',
                      style: TextStyle(
                        fontSize: Tokens.fontCaption,
                        fontWeight: Tokens.weightMedium,
                        color: Tokens.textPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 置顶按钮
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.windowService.isAlwaysOnTop,
                    builder: (context, isPinned, _) => _TitleBarButton(
                      icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      activeColor: isPinned ? Tokens.accent : null,
                      onPressed: () =>
                          widget.windowService.setAlwaysOnTop(!isPinned),
                    ),
                  ),
                  // 窗口控制按钮 (D-11)
                  _TitleBarButton(
                    icon: Icons.minimize,
                    onPressed: widget.windowService.minimize,
                  ),
                  _TitleBarButton(
                    icon: widget.windowService.isMaximized.value
                        ? Icons.filter_none
                        : Icons.crop_square,
                    onPressed: _toggleMaximize,
                  ),
                  _TitleBarButton(
                    icon: Icons.close,
                    isClose: true,
                    onPressed: widget.windowService.close,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 标题栏按钮 — 平面风格，hover 反馈
///
/// 设计决策 (D-11, D-15):
/// - 透明背景，hover 时显示 Tokens.titleBarHover
/// - 关闭按钮 hover 使用 Tokens.closeHoverBg
/// - 宽度 36px (Tokens.titleBarButtonWidth)
class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  final Color? activeColor;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
    this.activeColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  final _hovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, hovered, _) {
            return Container(
              width: Tokens.titleBarButtonWidth,
              height: Tokens.titleBarHeight,
              color: hovered
                  ? (widget.isClose
                        ? Tokens.closeHoverBg
                        : Tokens.titleBarHover)
                  : Colors.transparent,
              child: Icon(
                widget.icon,
                size: Tokens.iconSm,
                color:
                    widget.activeColor ??
                    (hovered ? Tokens.textPrimary : Tokens.textSecondary),
              ),
            );
          },
        ),
      ),
    );
  }
}
