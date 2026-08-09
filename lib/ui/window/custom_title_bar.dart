import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度
///
/// 全屏时整体透明 + 忽略交互。
class CustomTitleBar extends StatelessWidget {
  /// 应用标题是静态品牌标识，不随当前媒体或窗口状态变化。
  static const String _applicationTitle = 'Simple Player';

  final WindowBridge windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  Widget build(BuildContext context) {
    // 只有外层透明度和拖拽手势依赖完整窗口模式；按钮行作为 child 复用，
    // 避免全屏/最大化切换时重新构建标题、置顶、最小化和关闭按钮。
    final buttonRow = Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(left: Tokens.spMd),
          child: Text(
            _applicationTitle,
            style: TextStyle(
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
              color: Tokens.textPrimary,
            ),
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: windowService.isAlwaysOnTop,
          builder: (context, isPinned, _) => _TitleBarButton(
            icon: Icons.push_pin_outlined,
            isActive: isPinned,
            onPressed: () {
              unawaited(windowService.setAlwaysOnTop(!isPinned));
            },
          ),
        ),
        _TitleBarButton(
          icon: Icons.minimize,
          onPressed: () {
            unawaited(windowService.minimize());
          },
        ),
        ValueListenableBuilder<WindowMode>(
          valueListenable: windowService.mode,
          builder: (context, mode, _) {
            final isMaximized = mode.isMaximized;
            return _TitleBarButton(
              icon: isMaximized ? Icons.filter_none : Icons.crop_square,
              onPressed: () {
                unawaited(
                  windowService.setMode(
                    isMaximized ? WindowMode.windowed : WindowMode.maximized,
                  ),
                );
              },
            );
          },
        ),
        _TitleBarButton(
          icon: Icons.close,
          isClose: true,
          onPressed: () {
            unawaited(windowService.close());
          },
        ),
      ],
    );

    return AnimatedBuilder(
      animation: windowService.mode,
      child: buttonRow,
      builder: (context, buttons) {
        final isFullscreen = windowService.mode.value.isFullscreen;
        final isMaximized = windowService.mode.value.isMaximized;
        return AnimatedOpacity(
          opacity: isFullscreen ? 0.0 : 1.0,
          duration: const Duration(milliseconds: Tokens.durationFullscreenAnim),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: isFullscreen,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                unawaited(windowService.startDragging());
              },
              onDoubleTap: () {
                unawaited(
                  windowService.setMode(
                    isMaximized ? WindowMode.windowed : WindowMode.maximized,
                  ),
                );
              },
              child: Container(
                height: Tokens.titleBarHeight,
                color: Colors.transparent,
                child: buttons,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  final bool isActive;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? Tokens.accent : Tokens.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: Tokens.titleBarButtonWidth,
        height: Tokens.titleBarHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            hoverColor: isClose ? Tokens.closeHoverBg : Tokens.titleBarHover,
            highlightColor: isClose
                ? Tokens.closePressedBg
                : Tokens.titleBarPressed,
            splashColor: Colors.transparent,
            onTap: onPressed,
            child: Icon(icon, size: Tokens.iconSm, color: iconColor),
          ),
        ),
      ),
    );
  }
}
