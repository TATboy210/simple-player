import 'dart:async';

import '../../kernel/engine/engine_state.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
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

class _EmptyStateState extends State<EmptyState> with TickerProviderStateMixin {
  /// 给媒体纹理释放和空置页面切换预留的稳定窗口。
  static const _openButtonDelay = Duration(seconds: 2);

  late final AnimationController _dragAnim;
  late final CurvedAnimation _dragCurve;
  late final AnimationController _openButtonAnim;
  Timer? _openButtonDelayTimer;
  bool _isOpenButtonEnabled = false;

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
    _openButtonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationFade),
    );
    _scheduleOpenButton();
    // AnimatedBuilder 驱动重建，addListener+setState 会导致整个 build() 每帧重建
    // （包括 AuroraBackground），AnimatedBuilder 只重建包裹的子树

    if (widget.isDragHovering) {
      _dragAnim.forward();
    }
  }

  /// 延迟启用打开按钮，避免空置层刚显示时接收上一媒体会话的残留手势。
  void _scheduleOpenButton() {
    _openButtonDelayTimer?.cancel();
    if (widget.onOpenFile == null) return;

    _openButtonDelayTimer = Timer(_openButtonDelay, () {
      if (!mounted) return;
      setState(() => _isOpenButtonEnabled = true);
      _openButtonAnim.forward();
    });
  }

  @override
  void didUpdateWidget(EmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDragHovering != oldWidget.isDragHovering) {
      if (widget.isDragHovering) {
        _dragAnim.forward();
      } else {
        _dragAnim.reverse();
      }
    }
    if (widget.onOpenFile != oldWidget.onOpenFile) {
      _isOpenButtonEnabled = false;
      _openButtonAnim.value = 0;
      _scheduleOpenButton();
    }
  }

  @override
  void dispose() {
    _openButtonDelayTimer?.cancel();
    _openButtonAnim.dispose();
    _dragCurve.dispose();
    _dragAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 静态子组件 — 只构建一次，跨动画帧复用
    final openButton = FadeTransition(
      opacity: _openButtonAnim,
      child: GlassButton(
        icon: Icons.folder_open,
        label: l10n.openFile,
        tooltip: l10n.openFileTooltip,
        isPrimary: true,
        // GlassButton 将 null callback 同步为不可点、不可聚焦和禁用语义。
        onPressed: _isOpenButtonEnabled ? widget.onOpenFile : null,
      ),
    );
    final dragHint = _buildDragHint(context);

    return Stack(
      children: [
        // Layer 0: 极光呼吸背景（不参与动画，不重建）
        AuroraBackground(engineState: widget.engineState),

        // Layer 1: 居中悬浮内容 — AnimatedBuilder 只重建动画相关子树
        if (widget.onOpenFile != null)
          AnimatedBuilder(
            animation: _dragAnim,
            builder: (context, _) {
              return RepaintBoundary(
                child: Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBranding(context),
                      const SizedBox(height: Tokens.spXl),
                      SizedBox(
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FadeTransition(
                              opacity: ReverseAnimation(_dragCurve),
                              child: Transform.scale(
                                scale: 1.0 - 0.05 * _dragCurve.value,
                                child: openButton,
                              ),
                            ),
                            IgnorePointer(
                              child: FadeTransition(
                                opacity: _dragCurve,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - _dragCurve.value)),
                                  child: dragHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          Align(alignment: Alignment.center, child: _buildBranding(context)),
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
          style: const TextStyle(
            fontSize: Tokens.fontBranding,
            fontWeight: Tokens.weightExtraLight,
            color: Tokens.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.emptyStateSubtitle,
          style: const TextStyle(
            fontSize: Tokens.fontCaption,
            color: Tokens.textDisabled,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  /// 拖拽提示 — 毛玻璃容器 + 图标 + 文字
  Widget _buildDragHint(BuildContext context) {
    return GlassContainer(
      tier: GlassTier.thin,
      borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, size: 20, color: Tokens.accent),
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
