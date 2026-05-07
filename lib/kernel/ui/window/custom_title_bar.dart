import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/platform_service.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 毛玻璃 + 拖拽 + 窗口控制
///
/// 36px 高度（Win11 标准 32px + 4px 触摸目标）。
/// resize 时降级为纯色（跳过 BackdropFilter GPU 开销）。
class CustomTitleBar extends StatelessWidget {
  final VoidCallback? onOpenFile;
  final ValueNotifier<String>? fileName;

  const CustomTitleBar({super.key, this.onOpenFile, this.fileName});

  @override
  Widget build(BuildContext context) {
    final wm = PlatformService.I;

    final content = Container(
      height: Tokens.titleBarHeight,
      color: Tokens.bgGlass,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.play_circle_filled,
            size: Tokens.iconMd,
            color: Tokens.accent,
          ),
          const SizedBox(width: 8),
          if (fileName != null)
            ValueListenableBuilder<String>(
              valueListenable: fileName!,
              builder: (_, name, _) => Expanded(
                child: Text(
                  name.isEmpty ? 'Simple Player' : '$name — Simple Player',
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
          else
            const Text(
              'Simple Player',
              style: TextStyle(
                color: Tokens.textSecondary,
                fontSize: Tokens.fontCaption,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          const TitleBarControls(),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => wm.startDragging(),
      onDoubleTap: () => wm.toggleMaximize(),
      child: ValueListenableBuilder<bool>(
        valueListenable: wm.isResizing,
        builder: (_, resizing, child) => resizing
            ? child!
            : ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: Tokens.glassBlurThin,
                    sigmaY: Tokens.glassBlurThin,
                  ),
                  child: child,
                ),
              ),
        child: content,
      ),
    );
  }
}

/// 标题栏控制按钮组 — Pin / Minimize / Maximize / Close
class TitleBarControls extends StatelessWidget {
  const TitleBarControls({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wm = PlatformService.I;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin (always on top)
        ValueListenableBuilder<bool>(
          valueListenable: wm.isAlwaysOnTop,
          builder: (_, pinned, _) => _TitleBarButton(
            icon: Icons.push_pin,
            isActive: pinned,
            tooltip: pinned ? l10n.unpin : l10n.pin,
            onPressed: wm.toggleAlwaysOnTop,
          ),
        ),
        // Minimize
        _TitleBarButton(
          icon: Icons.minimize,
          tooltip: l10n.minimize,
          onPressed: wm.minimize,
        ),
        // Maximize
        ValueListenableBuilder<bool>(
          valueListenable: wm.isMaximized,
          builder: (_, maximized, _) => _TitleBarButton(
            icon: maximized ? Icons.filter_none : Icons.crop_square,
            tooltip: maximized ? l10n.restore : l10n.maximize,
            onPressed: wm.toggleMaximize,
          ),
        ),
        // Close
        _TitleBarButton(
          icon: Icons.close,
          tooltip: l10n.close,
          isClose: true,
          onPressed: wm.close,
        ),
      ],
    );
  }
}

/// 标题栏按钮 — 46×36，hover 高亮，close hover = danger 红底
class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isClose;

  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isClose = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovered
        ? (widget.isClose ? Tokens.danger : Tokens.bgHover)
        : Colors.transparent;
    final iconColor = _hovered
        ? Tokens.textPrimary
        : (widget.isActive ? Tokens.accent : Tokens.textSecondary);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: Tokens.titleBarButtonWidth,
            height: Tokens.titleBarHeight,
            color: bgColor,
            child: Icon(widget.icon, size: Tokens.iconSm, color: iconColor),
          ),
        ),
      ),
    );
  }
}
