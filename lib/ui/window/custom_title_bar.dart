import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../kernel/window_bridge/window_manager_service.dart';
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
          windowService: widget.windowService,
          child: child!,
        );
      },
      child: const RepaintBoundary(child: _TitleBarContent()),
    );
  }
}

/// 标题栏的可重绘内容：左侧标题/拖动区与右侧窗口控制组。
class _TitleBarContent extends StatelessWidget {
  const _TitleBarContent();

  @override
  Widget build(BuildContext context) {
    final windowService = context
        .dependOnInheritedWidgetOfExactType<_WindowServiceScope>()
        ?.service;
    if (windowService == null) return const SizedBox.shrink();

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
  final WindowBridge windowService;
  final Widget child;

  const _TitleBarAnimatedShell({
    required this.isFullscreen,
    required this.windowService,
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
    return _WindowServiceScope(
      service: windowService,
      isFullscreen: isFullscreen,
      child: Offstage(
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
      ),
    );
  }
}

/// 供标题栏内部传递窗口服务，避免重复创建或缓存已挂载的 Widget。
class _WindowServiceScope extends InheritedWidget {
  final WindowBridge service;

  /// 全屏态 — 拖动区上报据此清除原生 HTCAPTION 区域。
  final bool isFullscreen;

  const _WindowServiceScope({
    required this.service,
    required this.isFullscreen,
    required super.child,
  });

  @override
  bool updateShouldNotify(_WindowServiceScope oldWidget) =>
      oldWidget.service != service || oldWidget.isFullscreen != isFullscreen;
}

/// 标题栏可拖区 — 标题与左侧空白，负责窗口移动与双击最大化。
///
/// 两级实现：
/// 1. **原生（Windows）**：[_DragRegionReporter] 把本区域矩形上报给
///    runner，WM_NCHITTEST 回答 HTCAPTION——拖动、双击最大化/还原（系统
///    双击时间）、从最大化拖出还原、Aero Snap、右键系统菜单全部原生完成，
///    指针事件不再进入 Flutter。
/// 2. **手势兜底**（macOS/Linux 或上报失败）：
///    - onPanStart → startDragging（拖动窗口）
///    - onDoubleTap → setMode 在 maximized / windowed 之间切换
///
/// 区域必须撑满整条 32px 标题栏高度：Row 默认 center 交叉轴只给子项松约束，
/// 早期实现的命中区只有标题文字高度（实机元素树：y=8..25，17px），上下
/// 各约 7px 的空白既拖不动也双击不了。
///
/// 用 GestureDetector，不要用 Listener(onPointerDown)：
/// startDragging 的 WM_NCLBUTTONDOWN 会吞掉 up，破坏自写双击检测。
class _TitleBarDragArea extends StatelessWidget {
  final WindowBridge windowService;

  const _TitleBarDragArea({required this.windowService});

  @override
  Widget build(BuildContext context) {
    final isFullscreen =
        context
            .dependOnInheritedWidgetOfExactType<_WindowServiceScope>()
            ?.isFullscreen ??
        false;
    return _DragRegionReporter(
      windowService: windowService,
      enabled: !isFullscreen,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
      child: _buildGestureFallback(),
    );
  }

  Widget _buildGestureFallback() {
    return GestureDetector(
      key: const ValueKey('titlebar-drag-area'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        unawaited(windowService.startDragging());
      },
      onDoubleTap: () {
        final mode = windowService.mode.value;
        unawaited(
          windowService.setMode(
            mode.isMaximized ? WindowMode.windowed : WindowMode.maximized,
          ),
        );
      },
      // 撑满标题栏整高（见类注释）；标题文字在其中垂直居中。
      child: const SizedBox.expand(
        child: Align(alignment: Alignment.centerLeft, child: _TitleBarTitle()),
      ),
    );
  }
}

/// 把子树的全局矩形上报为原生标题栏拖动区（[WindowBridge.setTitleBarDragRegion]）。
///
/// 绘制后（post-frame）上报，矩形或 DPR 未变则跳过；[enabled] 为 false
/// （全屏）或卸载时清除——全屏下 Offstage 不再绘制，必须显式清除，否则
/// 残留的 HTCAPTION 区会让全屏窗口可被拖动（runner 侧另以 WS_CAPTION
/// 被摘除为第二道保险）。
class _DragRegionReporter extends SingleChildRenderObjectWidget {
  final WindowBridge windowService;
  final bool enabled;
  final double devicePixelRatio;

  const _DragRegionReporter({
    required this.windowService,
    required this.enabled,
    required this.devicePixelRatio,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDragRegionReporter(
        service: windowService,
        enabled: enabled,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDragRegionReporter renderObject,
  ) {
    renderObject
      ..service = windowService
      ..enabled = enabled
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderDragRegionReporter extends RenderProxyBox {
  _RenderDragRegionReporter({
    required this._service,
    required this._enabled,
    required this._devicePixelRatio,
  });

  WindowBridge _service;
  bool _enabled;
  double _devicePixelRatio;

  /// 最近一次上报的 (矩形, DPR) — 去重, 避免每帧 FFI 写属性。
  Rect? _reportedRect;
  double? _reportedRatio;
  bool _scheduled = false;

  set service(WindowBridge value) {
    if (identical(value, _service)) return;
    _clear();
    _service = value;
    markNeedsPaint();
  }

  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    // side effect: 全屏进入时立即清除原生拖动区 (Offstage 不再触发 paint)。
    if (!value) _clear();
    markNeedsPaint();
  }

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_enabled || _scheduled) return;
    _scheduled = true;
    // 位置在本帧绘制后才最终确定 — 帧后上报 (同 nativeapi MaximizeButtonArea)。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || !hasSize || !_enabled) return;
      final rect = localToGlobal(Offset.zero) & size;
      if (rect == _reportedRect && _devicePixelRatio == _reportedRatio) {
        return;
      }
      // 仅在平台接管时缓存 — 未接管 (非 Windows / 宿主未绑定) 下次绘制重试,
      // 手势兜底始终在位。
      if (_service.setTitleBarDragRegion(rect, _devicePixelRatio)) {
        _reportedRect = rect;
        _reportedRatio = _devicePixelRatio;
      }
    });
  }

  void _clear() {
    if (_reportedRect == null) return;
    _service.setTitleBarDragRegion(null, _devicePixelRatio);
    _reportedRect = null;
    _reportedRatio = null;
  }

  @override
  void detach() {
    _clear();
    super.detach();
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
