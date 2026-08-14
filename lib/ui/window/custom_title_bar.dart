import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_tooltip.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度。
///
/// 全屏时整体透明并忽略交互；窗口控制按钮始终由单一右侧控制组拥有，
/// 避免标题拖动区域与按钮布局分别管理响应式约束。
class CustomTitleBar extends StatefulWidget {
  final WindowBridge windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.windowService.mode,
      builder: (context, child) {
        final isFullscreen = widget.windowService.mode.value.isFullscreen;
        return _TitleBarAnimatedShell(
          isFullscreen: isFullscreen,
          windowService: widget.windowService,
          child: child!,
        );
      },
      child: const RepaintBoundary(child: _TitleBarContent()),
    );
  }
}

/// 标题栏的可重绘内容：左侧标题/拖动区与右侧窗口控制组。
class _TitleBarContent extends StatelessWidget {
  const _TitleBarContent();

  @override
  Widget build(BuildContext context) {
    final windowService = context
        .dependOnInheritedWidgetOfExactType<_WindowServiceScope>()
        ?.service;
    if (windowService == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final showPin = constraints.maxWidth >= Tokens.titleBarButtonWidth * 4;
        return Row(
          children: [
            const Expanded(child: _TitleBarTitle()),
            _TitleBarWindowControls(
              windowService: windowService,
              showPin: showPin,
            ),
          ],
        );
      },
    );
  }
}

/// 标题栏动画壳层 — 管理全屏透明度过渡与指针忽略。
class _TitleBarAnimatedShell extends StatelessWidget {
  final bool isFullscreen;
  final WindowBridge windowService;
  final Widget child;

  const _TitleBarAnimatedShell({
    required this.isFullscreen,
    required this.windowService,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _WindowServiceScope(
      service: windowService,
      child: AnimatedOpacity(
        opacity: isFullscreen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: Tokens.durationFullscreenAnim),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: isFullscreen,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => unawaited(windowService.startDragging()),
            onDoubleTap: () {
              final mode = windowService.mode.value;
              unawaited(
                windowService.setMode(
                  mode.isMaximized ? WindowMode.windowed : WindowMode.maximized,
                ),
              );
            },
            child: Container(
              height: Tokens.titleBarHeight,
              color: Colors.transparent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 供标题栏内部传递窗口服务，避免重复创建或缓存已挂载的 Widget。
class _WindowServiceScope extends InheritedWidget {
  final WindowBridge service;

  const _WindowServiceScope({required this.service, required super.child});

  @override
  bool updateShouldNotify(_WindowServiceScope oldWidget) =>
      oldWidget.service != service;
}

class _TitleBarTitle extends StatelessWidget {
  const _TitleBarTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: Tokens.spMd),
      child: Text(
        l10n.appTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: Tokens.fontCaption,
          fontWeight: Tokens.weightMedium,
          color: Tokens.textPrimary,
        ),
      ),
    );
  }
}

/// 标题栏右侧控制组，按置顶、最小化、最大化/还原、关闭排列。
class _TitleBarWindowControls extends StatelessWidget {
  final WindowBridge windowService;
  final bool showPin;

  const _TitleBarWindowControls({
    required this.windowService,
    required this.showPin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPin)
          ValueListenableBuilder<bool>(
            valueListenable: windowService.isAlwaysOnTop,
            builder: (context, isPinned, _) => _TitleBarButton(
              key: const ValueKey('titlebar-pin'),
              icon: Icons.push_pin_outlined,
              isActive: isPinned,
              tooltipMessage: isPinned ? l10n.unpin : l10n.pin,
              onPressed: () =>
                  unawaited(windowService.setAlwaysOnTop(!isPinned)),
            ),
          ),
        _TitleBarButton(
          key: const ValueKey('titlebar-minimize'),
          icon: Icons.minimize,
          tooltipMessage: l10n.minimize,
          onPressed: () => unawaited(windowService.minimize()),
        ),
        ValueListenableBuilder<WindowMode>(
          valueListenable: windowService.mode,
          builder: (context, mode, _) => _TitleBarButton(
            key: const ValueKey('titlebar-maximize-toggle'),
            icon: mode.isMaximized ? Icons.filter_none : Icons.crop_square,
            tooltipMessage: mode.isMaximized ? l10n.restore : l10n.maximize,
            onPressed: () => unawaited(
              windowService.setMode(
                mode.isMaximized ? WindowMode.windowed : WindowMode.maximized,
              ),
            ),
          ),
        ),
        _TitleBarButton(
          key: const ValueKey('titlebar-close'),
          icon: Icons.close,
          isClose: true,
          tooltipMessage: l10n.close,
          onPressed: () => unawaited(windowService.close()),
        ),
      ],
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  final bool isActive;
  final String? tooltipMessage;

  const _TitleBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
    this.isActive = false,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? Tokens.accent : Tokens.textSecondary;
    final content = MouseRegion(
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
    return AppTooltip(message: tooltipMessage, child: content);
  }
}
