import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

/// OSD 消息数据
class OsdMessage {
  const OsdMessage({required this.text, this.icon, this.progress});
  final String text;
  final IconData? icon;

  /// 0.0 ~ 1.0 极简进度条，null 则不显示
  final double? progress;
}

/// OSD 服务 — 全局单例，任意模块可调用
///
/// ```dart
/// OsdService.I.show('75%');
/// OsdService.I.show('75%', progress: 0.75);
/// OsdService.I.show('静音', icon: Icons.volume_off);
/// ```
class OsdService {
  OsdService._();
  static final I = OsdService._();

  /// 当前消息内容（驱动 UI 文字/图标更新）
  final message = ValueNotifier<OsdMessage?>(null);

  /// 是否可见（驱动动画入场/退场，与内容解耦）
  final _visible = ValueNotifier<bool>(false);
  ValueListenable<bool> get visible => _visible;

  Timer? _hideTimer;

  void show(
    String text, {
    IconData? icon,
    double? progress,
    Duration hold = const Duration(milliseconds: 1200),
  }) {
    _hideTimer?.cancel();
    message.value = OsdMessage(text: text, icon: icon, progress: progress);

    if (!_visible.value) {
      _visible.value = true; // 触发动画入场
    }
    // 已在显示时：只更新内容，动画保持在 1.0 不闪烁

    _hideTimer = Timer(hold, hide);
  }

  void hide() {
    _hideTimer?.cancel();
    if (_visible.value) {
      _visible.value = false; // 触发动画退场
    }
  }

  /// 由 overlay 退场动画完成后调用 — 仅当 service 确实要隐藏时清除内容
  void _onHidden() {
    if (!_visible.value) {
      message.value = null;
    }
  }
}

/// OSD 覆盖层 — 放在 widget 树根部，浮在最上层
///
/// - `IgnorePointer` 确保事件穿透到视频层
/// - 可见性动画与内容更新解耦：连续触发只更新文字，不闪烁
class OsdOverlay extends StatefulWidget {
  const OsdOverlay({super.key});

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _anim.addStatusListener(_onAnimStatus);
    OsdService.I.visible.addListener(_onVisibleChanged);
  }

  @override
  void dispose() {
    OsdService.I.visible.removeListener(_onVisibleChanged);
    _anim.removeStatusListener(_onAnimStatus);
    _anim.dispose();
    super.dispose();
  }

  void _onVisibleChanged() {
    if (OsdService.I.visible.value) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      OsdService.I._onHidden();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OsdService.I.visible,
      builder: (_, isVisible, _) {
        if (!isVisible && _anim.isDismissed) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ValueListenableBuilder<OsdMessage?>(
                valueListenable: OsdService.I.message,
                builder: (_, msg, _) => msg != null
                    ? _OsdBubble(message: msg)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// OSD 气泡 — 半透明沉浸式浮动提示
///
/// 双层 alpha 叠加自适应亮/暗视频：
/// - 暗底层 20% 黑保证亮视频上可读
/// - 文字 80% 白保证暗视频上可读
class _OsdBubble extends StatelessWidget {
  final OsdMessage message;
  const _OsdBubble({required this.message});

  static const _textColor = Color(0xCCFFFFFF);
  static const _bgColor = Color(0x33000000);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.icon != null) ...[
                Icon(message.icon, size: 22, color: _textColor),
                const SizedBox(width: 8),
              ],
              Text(
                message.text,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontFeatures: [Tokens.tabularFigures],
                ),
              ),
            ],
          ),
          if (message.progress != null) ...[
            const SizedBox(height: 8),
            _MiniProgressBar(value: message.progress!),
          ],
        ],
      ),
    );
  }
}

/// 极简进度条 — 4dp 高，半透明 accent
class _MiniProgressBar extends StatelessWidget {
  final double value;
  const _MiniProgressBar({required this.value});

  static const _trackColor = Color(0x22FFFFFF);
  static const _fillColor = Color(0xAA2C58F4);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: _trackColor,
          valueColor: const AlwaysStoppedAnimation<Color>(_fillColor),
          minHeight: 4,
        ),
      ),
    );
  }
}
