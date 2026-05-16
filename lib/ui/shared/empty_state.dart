import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/ui/theme/tokens.dart';
import 'aurora_background.dart';
import 'glass_container.dart';

/// 待机界面 — 极光呼吸背景 + 悬浮品牌文字 + 打开文件按钮
///
/// 拖拽动效：文件拖入时按钮渐变虚化，提示文字渐进实体化显示。
/// 视觉分层：
/// 1. AuroraBackground（3 个 Lissajous 光团）
/// 2. 居中悬浮内容（品牌名 + 操作按钮/拖拽提示），无边框沉浸式
class EmptyState extends StatefulWidget {
  final VoidCallback? onOpenFile;

  /// 文件拖拽悬停状态（由 DropHandler 通过父级传入）
  final bool isDragHovering;

  /// 播放引擎状态 — 传递给 AuroraBackground，非 idle 时暂停 Ticker
  final ValueNotifier<MediaState>? engineState;

  const EmptyState({
    super.key,
    this.onOpenFile,
    this.isDragHovering = false,
    this.engineState,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _dragAnim;
  late final CurvedAnimation _dragCurve;
  late final AnimationController _idleAnim;
  late final CurvedAnimation _idleCurve;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _dragAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      value: 0,
    );
    _dragCurve = CurvedAnimation(
      parent: _dragAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    // 用 addListener + setState 驱动重建，避免 AnimatedBuilder
    // 产生 _RenderLayoutSurrogateProxyBox 阻断 hit test
    _dragAnim.addListener(() => setState(() {}));

    _idleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      value: 0,
    );
    _idleCurve = CurvedAnimation(
      parent: _idleAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _idleAnim.addListener(() => setState(() {}));

    if (widget.isDragHovering) {
      _dragAnim.forward();
    } else {
      _startIdleTimer();
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !widget.isDragHovering) {
        _idleAnim.forward();
      }
    });
  }

  @override
  void didUpdateWidget(EmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDragHovering != oldWidget.isDragHovering) {
      if (widget.isDragHovering) {
        _idleTimer?.cancel();
        _idleAnim.reverse();
        _dragAnim.forward();
      } else {
        _dragAnim.reverse();
        _startIdleTimer();
      }
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleCurve.dispose();
    _idleAnim.dispose();
    _dragCurve.dispose();
    _dragAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        // Layer 0: 极光呼吸背景
        AuroraBackground(engineState: widget.engineState),

        // Layer 1: 居中悬浮内容
        Align(
          alignment: const Alignment(0, 0.1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 品牌名 ──
              _buildBranding(context),
              if (widget.onOpenFile != null) ...[
                const SizedBox(height: Tokens.spXl),
                // ── 按钮 + 拖拽提示（交叉淡入淡出） ──
                // addListener + setState 驱动，无需 AnimatedBuilder
                SizedBox(
                  height: 56, // 固定高度防止布局跳动
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 打开文件按钮 — 仅拖拽时淡出，闲置时保持可见
                      Opacity(
                        opacity: 1.0 - _dragCurve.value,
                        child: Transform.scale(
                          scale: 1.0 - 0.05 * _dragCurve.value,
                          child: GlassButton(
                            icon: Icons.folder_open,
                            label: l10n.openFile,
                            tooltip: l10n.openFileTooltip,
                            isPrimary: true,
                            respectResizeState: true,
                            onPressed: widget.onOpenFile!,
                          ),
                        ),
                      ),
                      // 拖拽提示 — 拖拽时淡入（IgnorePointer 阻止 BackdropFilter 拦截 hit test）
                      IgnorePointer(
                        child: Opacity(
                          opacity: _dragCurve.value,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - _dragCurve.value)),
                            child: _buildDragHint(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 闲置提示 — 5 秒后渐入，纯文字沉浸式
                IgnorePointer(
                  child: Opacity(
                    opacity: _idleCurve.value,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Tokens.spSm),
                      child: _buildIdleHint(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 品牌名 — 字间距拉宽，字重轻量
  Widget _buildBranding(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.brandName,
          style: TextStyle(
            fontSize: Tokens.fontBranding,
            fontWeight: Tokens.weightExtraLight,
            color: Tokens.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.emptyStateSubtitle,
          style: TextStyle(
            fontSize: Tokens.fontCaption,
            color: Tokens.textDisabled,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  /// 闲置提示 — 5 秒后显示的沉浸式纯文字
  Widget _buildIdleHint(BuildContext context) {
    return Text(
      AppLocalizations.of(context).dragHintIdle,
      style: const TextStyle(
        color: Tokens.textDisabled,
        fontSize: Tokens.fontCaption,
        letterSpacing: 1,
      ),
    );
  }

  /// 拖拽提示 — 毛玻璃容器 + 图标 + 文字
  Widget _buildDragHint(BuildContext context) {
    return GlassContainer(
      tier: GlassTier.thin,
      respectResizeState: true,
      borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_outline,
            size: 20,
            color: Tokens.accent,
          ),
          const SizedBox(width: Tokens.spSm),
          Text(
            AppLocalizations.of(context).dragHint,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
            ),
          ),
        ],
      ),
    );
  }
}
