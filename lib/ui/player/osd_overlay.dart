import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

/// OSD 浮动提示 — 显示临时消息（如音量变化、播放模式切换）
class OsdOverlay extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismissed;

  const OsdOverlay({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 2),
    this.onDismissed,
  });

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onDismissed?.call();
      }
    });
    _controller.forward();
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.duration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void didUpdateWidget(OsdOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _controller.forward(from: 0);
      _scheduleAutoHide();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spLg,
          vertical: Tokens.spSm,
        ),
        decoration: BoxDecoration(
          color: Tokens.bgGlass,
          borderRadius: BorderRadius.circular(Tokens.radiusPopup),
        ),
        child: Text(
          widget.message,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontBody,
          ),
        ),
      ),
    );
  }
}

/// 管理 OSD 消息的辅助 Widget
class OsdManager extends StatefulWidget {
  final Widget child;

  const OsdManager({super.key, required this.child});

  @override
  State<OsdManager> createState() => _OsdManagerState();
}

class _OsdManagerState extends State<OsdManager> {
  String? _message;
  Key _key = UniqueKey();

  void show(String message) {
    setState(() {
      _message = message;
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_message != null)
          Positioned(
            top: Tokens.controlBarHeight + 8,
            left: 0,
            right: 0,
            child: Center(
              child: OsdOverlay(
                key: _key,
                message: _message!,
                duration: const Duration(seconds: 2),
                onDismissed: () {
                  if (mounted) setState(() => _message = null);
                },
              ),
            ),
          ),
      ],
    );
  }
}
