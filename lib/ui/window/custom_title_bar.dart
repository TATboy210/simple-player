import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../kernel/window_bridge/window_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_tooltip.dart';
import '../theme/tokens.dart';

/// 自定义标题栏 — 平面/沉浸式按钮，32px 高度。
///
/// 全屏时整体收起（不占布局、不绘制、不命中，视频铺满到顶）；窗口控制
/// 按钮始终由单一右侧控制组拥有，
/// 避免标题拖动区域与按钮布局分别管理响应式约束。
// DCM avoid-unnecessary-stateful-widgets: State 持有窗口生命周期回调注册,
// 保守保留 StatefulWidget (转换风险 > 风格收益).
// ignore: avoid-unnecessary-stateful-widgets
class CustomTitleBar extends StatefulWidget {
  final WindowBridge windowService;

  const CustomTitleBar({super.key, required this.windowService});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.windowService.mode,
      builder: (context, child) {
        final isFullscreen = widget.windowService.mode.value.isFullscreen;
        return _TitleBarAnimatedShell(
          isFullscreen: isFullscreen,
          child: child!,
        );
      },
      child: RepaintBoundary(
        child: _TitleBarContent(windowService: widget.windowService),
      ),
    );
  }
}

/// 标题栏的可重绘内容：左侧标题/拖动区与右侧窗口控制组。
class _TitleBarContent extends StatelessWidget {
  final WindowBridge windowService;

  const _TitleBarContent({required this.windowService});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPin = constraints.maxWidth >= Tokens.titleBarButtonWidth * 4;
        return Row(
          children: [
            Expanded(
              // 仅标题/空白 Expanded 区域响应 pan 拖动与双击最大化；
              // 右侧按钮组独立持有点击，不进入拖拽手势竞争。
              child: _TitleBarDragArea(windowService: windowService),
            ),
            _TitleBarWindowControls(
              windowService: windowService,
              showPin: showPin,
            ),
          ],
        );
      },
    );
  }
}

/// 标题栏动画壳层 — 管理全屏透明度过渡与指针忽略。
class _TitleBarAnimatedShell extends StatelessWidget {
  final bool isFullscreen;
  final Widget child;

  const _TitleBarAnimatedShell({
    required this.isFullscreen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 手势不放在整行壳层：translucent GestureDetector 会先于子树命中，
    // 右侧按钮的点击会被 pan 竞争劫持。这里只负责全屏收起/淡入，
    // 拖动与双击最大化由 [_TitleBarDragArea]（标题 Expanded 区域）持有。
    //
    // 全屏用 Offstage 收起整条 32px 槽位：mpv_kit 全屏不再推独立 route，
    // 视频仍在 PlayerScreen 的 Column 里排在标题栏之下——只把标题栏透明化
    // 会留下一条 bgBase 色空带（实机截图：全屏顶部约 32px 深色条，即用户
    // 看到的「全屏仍有标题栏」）。Offstage 保持子树挂载（identity 不变），
    // 退出全屏时 AnimatedOpacity 仍从 0 淡入。
    return Offstage(
      offstage: isFullscreen,
      child: AnimatedOpacity(
        opacity: isFullscreen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: Tokens.durationFullscreenAnim),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: isFullscreen,
          child: SizedBox(height: Tokens.titleBarHeight, child: child),
        ),
      ),
    );
  }
}

/// 标题栏可拖区 — 标题与左侧空白，负责窗口移动与双击最大化。
///
/// 手势交给系统（nativeapi）：
/// - onPanStart → startDragging（系统拖动循环，保留 Aero Snap）
/// - onDoubleTap → 系统标题栏双击动作（最大化/还原，随系统设置）
///
/// 不提供右键系统菜单：nativeapi 的 ShowSystemMenu 不 marshal 到窗口线程，
/// 在 runner 的独立 UI 线程模式下 SetWindowSubclass 跨线程失败，菜单弹不出。
///
/// 区域必须撑满整条 32px 标题栏高度：Row 默认 center 交叉轴只给子项松约束，
/// 命中区曾只有标题文字高度（17px），上下空白既拖不动也双击不了。
///
/// 用 GestureDetector，不要用 Listener(onPointerDown)：
/// startDragging 的 WM_NCLBUTTONDOWN 会吞掉 up，破坏双击检测。
class _TitleBarDragArea extends StatelessWidget {
  final WindowBridge windowService;

  const _TitleBarDragArea({required this.windowService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('titlebar-drag-area'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(windowService.startDragging()),
      onDoubleTap: windowService.titleBarDoubleClick,
      // 撑满标题栏整高（见类注释）；标题文字在其中垂直居中。
      child: const SizedBox.expand(
        child: Align(alignment: Alignment.centerLeft, child: _TitleBarTitle()),
      ),
    );
  }
}

class _TitleBarTitle extends StatelessWidget {
  const _TitleBarTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: Tokens.spMd),
      child: Text(
        l10n.appTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: Tokens.fontCaption,
          fontWeight: Tokens.weightMedium,
          color: Tokens.textPrimary,
        ),
      ),
    );
  }
}

/// 标题栏右侧控制组，按置顶、最小化、最大化/还原、关闭排列。
class _TitleBarWindowControls extends StatelessWidget {
  final WindowBridge windowService;
  final bool showPin;

  const _TitleBarWindowControls({
    required this.windowService,
    required this.showPin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPin)
          ValueListenableBuilder<bool>(
            valueListenable: windowService.isAlwaysOnTop,
            builder: (context, isPinned, _) => _TitleBarButton(
              key: const ValueKey('titlebar-pin'),
              icon: Icons.push_pin_outlined,
              isActive: isPinned,
              tooltipMessage: isPinned ? l10n.unpin : l10n.pin,
              onPressed: () =>
                  unawaited(windowService.setAlwaysOnTop(!isPinned)),
            ),
          ),
        _TitleBarButton(
          key: const ValueKey('titlebar-minimize'),
          icon: Icons.minimize,
          tooltipMessage: l10n.minimize,
          onPressed: () => unawaited(windowService.minimize()),
        ),
        ValueListenableBuilder<WindowMode>(
          valueListenable: windowService.mode,
          builder: (context, mode, _) => _TitleBarButton(
            key: const ValueKey('titlebar-maximize-toggle'),
            icon: mode.isMaximized ? Icons.filter_none : Icons.crop_square,
            tooltipMessage: mode.isMaximized ? l10n.restore : l10n.maximize,
            onPressed: () => unawaited(
              windowService.setMode(
                mode.isMaximized ? WindowMode.windowed : WindowMode.maximized,
              ),
            ),
          ),
        ),
        _TitleBarButton(
          key: const ValueKey('titlebar-close'),
          icon: Icons.close,
          isClose: true,
          tooltipMessage: l10n.close,
          onPressed: () => unawaited(windowService.close()),
        ),
      ],
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  final bool isActive;
  final String? tooltipMessage;

  const _TitleBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
    this.isActive = false,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? Tokens.accent : Tokens.textSecondary;
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: Tokens.titleBarButtonWidth,
        height: Tokens.titleBarHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // v0.0.6.2: 显式食指光标 — 与 GlassButton 同根因, InkWell 内置
            // MouseRegion 处于命中路径最深层, 解析值 (箭头) 会覆盖外层
            // MouseRegion 的 click; 不显式传则整组窗口按钮均为箭头.
            mouseCursor: SystemMouseCursors.click,
            hoverColor: isClose ? Tokens.closeHoverBg : Tokens.titleBarHover,
            highlightColor: isClose
                ? Tokens.closePressedBg
                : Tokens.titleBarPressed,
            splashColor: Colors.transparent,
            onTap: onPressed,
            child: Icon(icon, size: Tokens.iconSm, color: iconColor),
          ),
        ),
      ),
    );
    return AppTooltip(message: tooltipMessage, child: content);
  }
}
