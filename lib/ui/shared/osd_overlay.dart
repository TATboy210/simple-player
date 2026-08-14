import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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

  /// 是否可见（驱动显示/隐藏）
  final _visible = ValueNotifier<bool>(false);
  ValueListenable<bool> get visible => _visible;

  Timer? _hideTimer;

  void show(
    String text, {
    IconData? icon,
    double? progress,
    Duration hold = const Duration(milliseconds: Tokens.osdDefaultHoldMs),
  }) {
    _hideTimer?.cancel();
    _hideTimer = Timer(hold, hide);

    if (!_visible.value) _visible.value = true;
    message.value = OsdMessage(text: text, icon: icon, progress: progress);
  }

  void hide() {
    _hideTimer?.cancel();
    _visible.value = false;
    message.value = null;
  }
}

/// OSD 覆盖层 — 放在 widget 树根部，浮在最上层
///
/// - `IgnorePointer` 确保事件穿透到视频层
/// - 只监听 message，visible 通过 message==null 判断
/// - AnimatedOpacity 淡入/淡出，AnimatedSwitcher 文本交叉淡入
/// - `resizing` 信号：resize 期间跳过 OSD 内容构建
class OsdOverlay extends StatefulWidget {
  /// Window resize signal — when true, skip rebuild to save CPU.
  final ValueListenable<bool>? resizing;

  const OsdOverlay({super.key, this.resizing});

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay> {
  OsdMessage? _messageAtResizeStart;

  @override
  void initState() {
    super.initState();
    widget.resizing?.addListener(_handleResizeChanged);
    if (widget.resizing?.value ?? false) {
      _messageAtResizeStart = OsdService.I.message.value;
    }
  }

  @override
  void didUpdateWidget(covariant OsdOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_handleResizeChanged);
      widget.resizing?.addListener(_handleResizeChanged);
      _messageAtResizeStart = (widget.resizing?.value ?? false)
          ? OsdService.I.message.value
          : null;
    }
  }

  @override
  void dispose() {
    widget.resizing?.removeListener(_handleResizeChanged);
    super.dispose();
  }

  void _handleResizeChanged() {
    final resizing = widget.resizing?.value ?? false;
    if (resizing) {
      _messageAtResizeStart = OsdService.I.message.value;
    } else {
      _messageAtResizeStart = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OsdMessage?>(
      valueListenable: OsdService.I.message,
      builder: (_, msg, _) {
        final resizing = widget.resizing?.value ?? false;
        final visibleMessage = resizing ? _messageAtResizeStart : msg;
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: visibleMessage != null ? 1.0 : 0.0,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            child: visibleMessage != null
                ? Center(
                    child: RepaintBoundary(
                      child: _OsdBubble(message: visibleMessage),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  static const _fadeDuration = Duration(milliseconds: Tokens.osdFadeDurationMs);
}

/// OSD 气泡 — 纯文字 + 可选图标/进度条
class _OsdBubble extends StatelessWidget {
  final OsdMessage message;
  const _OsdBubble({required this.message});

  static const _textStyle = TextStyle(
    color: Tokens.textPrimary,
    fontSize: Tokens.fontTitle,
    fontWeight: Tokens.weightRegular,
    fontFeatures: [Tokens.tabularFigures],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.icon != null) ...[
              Icon(
                message.icon,
                size: Tokens.osdIconSize,
                color: Tokens.textPrimary,
              ),
              const SizedBox(width: 8),
            ],
            Text(message.text, style: _textStyle),
          ],
        ),
        if (message.progress != null) ...[
          const SizedBox(height: 8),
          // ?? 0 防御消除 `!` (progress 已 null 检查, 属性不提升)
          _MiniProgressBar(value: message.progress ?? 0),
        ],
      ],
    );
  }
}

/// 极简进度条 — 4dp 高，半透明 accent，即时响应
class _MiniProgressBar extends StatelessWidget {
  final double value;
  const _MiniProgressBar({required this.value});

  static const _trackColor = Tokens.osdTrackColor;
  static const _fillAnim = AlwaysStoppedAnimation<Color>(Tokens.accent);

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
          valueColor: _fillAnim,
          minHeight: 4,
        ),
      ),
    );
  }
}
