import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度
///
/// 全屏时整体透明 + 忽略交互。
///
/// 性能优化（PC 窗口频繁切换场景）：
/// - StatefulWidget 缓存静态按钮行（标题、pin、最小化、关闭），
///   避免窗口模式变更时重复创建相同 widget 子树。
/// - 动画壳层（AnimatedOpacity/IgnorePointer/GestureDetector）仅在进入/
///   离开全屏时触发动画，最大化↔恢复切换跳过透明动效以减少 GPU 开销。
/// - 静态标题行被 RepaintBoundary 包裹，与动态按钮子树隔离重绘区域。
class CustomTitleBar extends StatefulWidget {
  /// 应用标题是静态品牌标识，不随当前媒体或窗口状态变化。
  static const String applicationTitle = 'Simple Player';

  final WindowBridge windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  /// 静态按钮行（标题 + pin + minimize + close）在 initState 中构建一次，
  /// 之后每次 build 复用同一实例，避免重复创建相同的 ConstWidget 子树。
  late final Widget _staticTitleRow;

  @override
  void initState() {
    super.initState();
    _staticTitleRow = _buildStaticTitleRow();
  }

  @override
  void didUpdateWidget(covariant CustomTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowService != widget.windowService) {
      // WindowBridge 替换时同步更新缓存
      _staticTitleRow = _buildStaticTitleRow();
    }
  }

  /// 构建静态标题行 — pin、最小化、关闭按钮及标题文字不随模式变化。
  Widget _buildStaticTitleRow() {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(left: Tokens.spMd),
          child: Text(
            CustomTitleBar.applicationTitle,
            style: TextStyle(
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
              color: Tokens.textPrimary,
            ),
          ),
        ),
        const Spacer(),
        // Pin 按钮 — 独立 ValueListenableBuilder，仅当置顶状态变化时重建。
        ValueListenableBuilder<bool>(
          valueListenable: widget.windowService.isAlwaysOnTop,
          builder: (context, isPinned, _) {
            return _TitleBarButton(
              icon: Icons.push_pin_outlined,
              isActive: isPinned,
              onPressed: () {
                unawaited(
                  widget.windowService.setAlwaysOnTop(!isPinned),
                );
              },
            );
          },
        ),
        // 最小化按钮 — 无状态监听。
        _TitleBarButton(
          icon: Icons.minimize,
          onPressed: () {
            unawaited(widget.windowService.minimize());
          },
        ),
        // 关闭按钮 — 无状态监听。
        _TitleBarButton(
          icon: Icons.close,
          onPressed: () {
            unawaited(widget.windowService.close());
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder：child（静态行）由 Flutter 框架缓存在每次 rebuild 间，
    // builder 仅创建动画壳层（AnimatedOpacity + IgnorePointer + GestureDetector），
    // 避免全屏/非全屏切换时重建静态按钮子树。
    return AnimatedBuilder(
      animation: widget.windowService.mode,
      builder: (context, child) {
        final isFullscreen = widget.windowService.mode.value.isFullscreen;
        return _TitleBarAnimatedShell(
          isFullscreen: isFullscreen,
          windowService: widget.windowService,
          child: child!,
        );
      },
      child: RepaintBoundary(
        child: _DynamicTitleRow(
          windowService: widget.windowService,
          staticTitleRow: _staticTitleRow,
        ),
      ),
    );
  }
}

/// 标题栏动画壳层 — 管理全屏透明度过渡与指针忽略。
///
/// 仅在进入/离开全屏时触发 AnimatedOpacity 动画。
/// 最大化↔恢复切换（isMaximized 变化但非全屏）不触发动画，
/// 避免 GPU readback 抖动导致的卡顿。
class _TitleBarAnimatedShell extends StatelessWidget {
  final bool isFullscreen;
  final WindowBridge windowService;
  final Widget child;

  const _TitleBarAnimatedShell({
    required this.isFullscreen,
    required this.windowService,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isFullscreen ? 0.0 : 1.0,
      duration: const Duration(milliseconds: Tokens.durationFullscreenAnim),
      curve: Curves.easeInOut,
      child: IgnorePointer(
        ignoring: isFullscreen,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) {
            unawaited(windowService.startDragging());
          },
          onDoubleTap: () {
            final m = windowService.mode.value;
            unawaited(
              windowService.setMode(
                m.isMaximized ? WindowMode.windowed : WindowMode.maximized,
              ),
            );
          },
          child: Container(
            height: Tokens.titleBarHeight,
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 标题栏动态内容 — 静态行（缓存于 RepaintBoundary 中）与
/// 最大化/恢复按钮并排列放。最大化按钮独立监听模式变更，仅在
/// isMaximized 变化时刷新自身。
class _DynamicTitleRow extends StatelessWidget {
  final WindowBridge windowService;
  final Widget staticTitleRow;

  const _DynamicTitleRow({
    required this.windowService,
    required this.staticTitleRow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        staticTitleRow,
        // 最大化按钮 — 独立监听模式变更，仅在 isMaximized 翻转时更新图标。
        ValueListenableBuilder<WindowMode>(
          valueListenable: windowService.mode,
          builder: (context, mode, _) {
            return _TitleBarButton(
              icon: mode.isMaximized ? Icons.filter_none : Icons.crop_square,
              onPressed: () {
                unawaited(
                  windowService.setMode(
                    mode.isMaximized ? WindowMode.windowed : WindowMode.maximized,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════ 通用标题栏按钮 ═══════════════

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? Tokens.accent : Tokens.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: Tokens.titleBarButtonWidth,
        height: Tokens.titleBarHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            hoverColor: Tokens.titleBarHover,
            highlightColor: Tokens.titleBarPressed,
            splashColor: Colors.transparent,
            onTap: onPressed,
            child: Icon(icon, size: Tokens.iconSm, color: iconColor),
          ),
        ),
      ),
    );
  }
}
