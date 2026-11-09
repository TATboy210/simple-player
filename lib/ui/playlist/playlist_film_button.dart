import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'playlist_tokens.dart';

/// 透明"塑料膜"按钮分区 — 覆盖缩略图的一片区域, 交互三态:
/// 静置完全透明 (缩略图焦点不受损), hover 微亮 (white 6%), 按下变暗
/// (black 12%, pointer-down 即时 — Apple fluid interfaces §1).
///
/// 两段延迟揭示 (用户钦定): hover 0.4s 后图标渐显 (居中), 再 1s 后功能名
/// 渐进展示 — [ClipRect] 内 `Align(widthFactor)` 由 [TweenAnimationBuilder]
/// 驱动文字展开, 图标被自然推左; 移出立即反向渐退 (计时器作废, 两态同帧
/// 回落, [AnimatedOpacity]/widthFactor 各自渐退).
class PlaylistFilmButton extends StatefulWidget {
  /// 创建塑料膜按钮分区.
  const PlaylistFilmButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  /// 揭示的功能图标.
  final IconData icon;

  /// 揭示的功能名.
  final String label;

  /// null = 禁用 (如无断点的续播) — 不响应点击, hover 无反馈.
  final VoidCallback? onTap;

  /// 禁用态显式标记 — 与 onTap == null 同源传入, 驱动图标淡化.
  final bool enabled;

  @override
  State<PlaylistFilmButton> createState() => _PlaylistFilmButtonState();
}

class _PlaylistFilmButtonState extends State<PlaylistFilmButton> {
  bool _hovering = false;
  bool _pressed = false;

  /// 两段延迟揭示状态 — hover 后图标渐显, 再隔一段文字展开.
  bool _iconShown = false;
  bool _textShown = false;
  Timer? _iconTimer;
  Timer? _textTimer;

  /// 图标显现的 hover 延迟 (用户钦定 0.4s).
  static const _iconDelay = Duration(
    milliseconds: PlaylistTokens.filmIconDelayMs,
  );

  /// 文字展开距图标显现的间隔 (用户钦定再 1s).
  static const _textDelay = Duration(
    milliseconds: PlaylistTokens.filmTextDelayMs,
  );

  static const _fadeDuration = Duration(
    milliseconds: Tokens.durationControlsFade,
  );

  bool get _enabled => widget.enabled && widget.onTap != null;

  /// 背景色三态 — 按下变暗 > hover 微亮 > 透明.
  Color get _background {
    if (_pressed) {
      return Colors.black.withValues(alpha: PlaylistTokens.filmPressedAlpha);
    }
    if (_hovering && _enabled) {
      return Colors.white.withValues(alpha: PlaylistTokens.filmHoverAlpha);
    }
    return Colors.transparent;
  }

  void _onEnter() {
    setState(() => _hovering = true);
    if (!_enabled) return;
    _iconTimer = Timer(_iconDelay, () {
      if (!mounted) return;
      setState(() => _iconShown = true);
      _textTimer = Timer(_textDelay, () {
        if (mounted) setState(() => _textShown = true);
      });
    });
  }

  void _onExit() {
    // 移出立即反向渐退 — 计时器作废, 两态同帧回落 (AnimatedOpacity 与
    // widthFactor 各自渐退), 未触发的延迟揭示不再发生.
    _iconTimer?.cancel();
    _textTimer?.cancel();
    _iconTimer = null;
    _textTimer = null;
    setState(() {
      _hovering = false;
      _pressed = false;
      _iconShown = false;
      _textShown = false;
    });
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: PlaylistTokens.filmPressMs),
          color: _background,
          padding: const EdgeInsets.symmetric(
            horizontal: PlaylistTokens.filmHPadding,
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  /// 图标 + 渐显文字 — 图标 hover 后渐显 (居中), 文字再隔一段
  /// widthFactor 0→1 展开, 图标被推左.
  Widget _buildContent() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: _iconShown && _enabled ? 1.0 : 0.0,
            duration: _fadeDuration,
            child: Icon(
              widget.icon,
              size: PlaylistTokens.filmIconSize,
              color: _enabled ? Tokens.textPrimary : Tokens.textSecondary,
            ),
          ),
          // 渐显文字区 — ClipRect + widthFactor 0→1 (展开推图标左移);
          // 静置宽 0 不占位, 缩略图焦点不受损.
          ClipRect(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _textShown && _enabled ? 1.0 : 0.0),
              duration: _fadeDuration,
              curve: Curves.easeInOut,
              builder: (_, width, child) => Align(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                heightFactor: 1.0,
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: PlaylistTokens.filmLabelGap,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: PlaylistTokens.filmLabelFontSize,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
