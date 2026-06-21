import 'package:flutter/material.dart';

import '../../infra/event_bus/event_bus.dart';
import '../../core/events/window_events.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 通过 EventBus 发送 WindowCommand
///
/// 监听 WindowEvent 更新全屏/最大化/置顶状态，
/// 支持拖拽移动窗口、双击最大化、三键控制。
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.bus});

  final EventBus bus;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WindowEvent>(
      stream: bus.on<WindowEvent>(),
      builder: (context, snapshot) {
        final isFullscreen = _isFullscreen(snapshot.data);
        final isMaximized = _isMaximized(snapshot.data);

        return AnimatedOpacity(
          opacity: isFullscreen ? 0.0 : 1.0,
          duration: const Duration(
            milliseconds: Tokens.durationFullscreenAnim,
          ),
          child: IgnorePointer(
            ignoring: isFullscreen,
            child: GestureDetector(
              onPanStart: (_) => bus.fire(const StartDraggingCommand()),
              onDoubleTap: () => bus.fire(const ToggleMaximizeCommand()),
              child: Container(
                height: Tokens.titleBarHeight,
                color: Colors.transparent,
                child: Row(
                  children: [
                    const SizedBox(width: Tokens.spMd),
                    Text(
                      'Simple Player',
                      style: TextStyle(
                        color: Tokens.textSecondary,
                        fontSize: Tokens.fontCaption,
                        fontWeight: Tokens.weightMedium,
                      ),
                    ),
                    const Spacer(),
                    _PinButton(bus: bus),
                    _TitleBarButton(
                      icon: Icons.minimize,
                      onPressed: () => bus.fire(const MinimizeCommand()),
                    ),
                    _TitleBarButton(
                      icon: isMaximized
                          ? Icons.filter_none
                          : Icons.crop_square,
                      onPressed: () =>
                          bus.fire(const ToggleMaximizeCommand()),
                    ),
                    _TitleBarButton(
                      icon: Icons.close,
                      isClose: true,
                      onPressed: () => bus.fire(const CloseCommand()),
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

  static bool _isFullscreen(WindowEvent? event) {
    if (event is FullscreenChanged) return event.value;
    return false;
  }

  static bool _isMaximized(WindowEvent? event) {
    if (event is MaximizeChanged) return event.value;
    return false;
  }
}

/// 置顶按钮 — 独立监听 AlwaysOnTopChanged 事件
class _PinButton extends StatelessWidget {
  const _PinButton({required this.bus});

  final EventBus bus;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AlwaysOnTopChanged>(
      stream: bus.on<AlwaysOnTopChanged>(),
      builder: (context, snapshot) {
        final isPinned = snapshot.data?.value ?? false;
        return _TitleBarButton(
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          onPressed: () =>
              bus.fire(SetAlwaysOnTopCommand(!isPinned)),
        );
      },
    );
  }
}

/// 标题栏按钮 — hover/press 视觉反馈
class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;
  bool _pressed = false;

  Color get _backgroundColor {
    if (widget.isClose) {
      if (_pressed) return Tokens.closePressedBg;
      if (_hovering) return Tokens.closeHoverBg;
    } else {
      if (_pressed) return Tokens.titleBarPressed;
      if (_hovering) return Tokens.titleBarHover;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: Tokens.titleBarButtonWidth,
          height: Tokens.titleBarHeight,
          color: _backgroundColor,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: Tokens.iconSm,
            color: widget.isClose && _hovering
                ? Tokens.textPrimary
                : Tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
