import 'dart:async';
import 'package:flutter/material.dart';

import '../player/osd_service.dart';
import '../theme/tokens.dart';

/// OSD 浮层 — 显示播放状态反馈（音量、播放/暂停等）
///
/// IgnorePointer 确保不拦截下层手势。
/// 每次收到新消息时重置淡入淡出动画。
class OsdOverlay extends StatefulWidget {
  const OsdOverlay({super.key});

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  String _text = '';
  Timer? _holdTimer;
  StreamSubscription<OsdMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.osdFadeDurationMs),
    );
    _sub = OsdService.instance.messages.listen(_onMessage);
  }

  void _onMessage(OsdMessage msg) {
    _holdTimer?.cancel();
    setState(() => _text = msg.text);
    _anim.forward(from: 0);
    _holdTimer = Timer(Duration(milliseconds: msg.holdMs), () {
      if (mounted) _anim.reverse();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _sub?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _anim,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Tokens.controlBg,
              borderRadius: BorderRadius.circular(Tokens.radiusS),
            ),
            child: Text(
              _text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: Tokens.fontBody,
                fontWeight: Tokens.weightMedium,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
