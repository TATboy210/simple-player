import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/window/aspect_ratio_service.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 毛玻璃 + 拖拽 + 窗口控制
///
/// 36px 高度（Win11 标准 32px + 4px 触摸目标）。
/// resize 时条件渲染跳过 BackdropFilter（零合成开销）。
class CustomTitleBar extends StatelessWidget {
  final VoidCallback? onOpenFile;
  final ValueNotifier<String>? fileName;

  const CustomTitleBar({super.key, this.onOpenFile, this.fileName});

  @override
  Widget build(BuildContext context) {
    final wm = WindowBridge.I;

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
                    fontWeight: Tokens.weightMedium,
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
                fontWeight: Tokens.weightMedium,
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
      child: ValueListenableBuilder<WindowInteractionState>(
        valueListenable: wm.interaction,
        child: content,
        builder: (_, state, child) => SizedBox(
          height: Tokens.titleBarHeight,
          child: state == WindowInteractionState.idle
              ? ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: Tokens.glassBlurThin,
                      sigmaY: Tokens.glassBlurThin,
                    ),
                    child: RepaintBoundary(child: child!),
                  ),
                )
              : child!,
        ),
      ),
    );
  }
}

/// 标题栏控制按钮组 — Pin / Minimize / Maximize / Close
///
/// resize 时通过 IgnorePointer 统一禁用所有按钮交互。
class TitleBarControls extends StatelessWidget {
  const TitleBarControls({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wm = WindowBridge.I;
    return ValueListenableBuilder<WindowInteractionState>(
      valueListenable: wm.interaction,
      builder: (_, state, child) => IgnorePointer(
        ignoring: state != WindowInteractionState.idle,
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aspect ratio cycle (visible when ratio is locked)
          ValueListenableBuilder<double>(
            valueListenable: AspectRatioService.I.ratioNotifier,
            builder: (_, ratio, _) {
              if (ratio <= 0) return const SizedBox.shrink();
              return _TitleBarButton(
                icon: Icons.aspect_ratio,
                tooltip: _aspectRatioLabel(ratio, l10n),
                onPressed: () => AspectRatioService.I.cycleRatio(),
              );
            },
          ),
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
      ),
    );
  }
}

/// 宽高比标签本地化 — 标准比例用 l10n key，数值比例用 fallback
String _aspectRatioLabel(double ratio, AppLocalizations l10n) {
  if ((ratio - 16.0 / 9.0).abs() < 0.01) return '16:9';
  if ((ratio - 4.0 / 3.0).abs() < 0.01) return '4:3';
  if ((ratio - 21.0 / 9.0).abs() < 0.01) return '21:9';
  return '${ratio.toStringAsFixed(2)}:1';
}

/// 标题栏按钮 — 46×36，hover 高亮，close hover = danger 红底
///
/// resize 期间由父级 TitleBarControls 的 IgnorePointer 统一禁用，
/// 按钮自身不再监听 isResizing。
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
