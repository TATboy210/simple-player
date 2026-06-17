import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_service.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度
///
/// 全屏时整体透明 + 忽略交互。
class CustomTitleBar extends StatelessWidget {
  final WindowService windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: windowService.isFullscreen,
      builder: (context, isFullscreen, _) {
        return AnimatedOpacity(
          opacity: isFullscreen ? 0.0 : 1.0,
          duration:
              const Duration(milliseconds: Tokens.durationFullscreenAnim),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: isFullscreen,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                unawaited(windowService.startDragging());
              },
              onDoubleTap: () {
                if (windowService.isMaximized.value) {
                  unawaited(windowService.restore());
                } else {
                  unawaited(windowService.maximize());
                }
              },
              child: Container(
                height: Tokens.titleBarHeight,
                color: Colors.transparent,
                child: Row(
                  children: [
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
                    ValueListenableBuilder<bool>(
                      valueListenable: windowService.isAlwaysOnTop,
                      builder: (context, isPinned, _) => _TitleBarButton(
                        icon: Icons.push_pin_outlined,
                        isActive: isPinned,
                        onPressed: () {
                          unawaited(
                            windowService.setAlwaysOnTop(!isPinned),
                          );
                        },
                      ),
                    ),
                    _TitleBarButton(
                      icon: Icons.minimize,
                      onPressed: () {
                        unawaited(windowService.minimize());
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: windowService.isMaximized,
                      builder: (context, isMax, _) => _TitleBarButton(
                        icon: isMax
                            ? Icons.filter_none
                            : Icons.crop_square,
                        onPressed: () {
                          if (isMax) {
                            unawaited(windowService.restore());
                          } else {
                            unawaited(windowService.maximize());
                          }
                        },
                      ),
                    ),
                    _TitleBarButton(
                      icon: Icons.close,
                      isClose: true,
                      onPressed: () {
                        unawaited(windowService.close());
                      },
                    ),
                  ],
                ),
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
            hoverColor:
                isClose ? Tokens.closeHoverBg : Tokens.titleBarHover,
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
