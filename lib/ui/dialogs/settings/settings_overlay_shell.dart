// SettingsOverlayShell — Phase 23 设置覆盖层壳（PANEL-03/04/05/06/07）。
//
// 在 PlayerScreen 内容区 Stack 顶层树内挂载（D-05，非 showDialog），由
// SettingsPanelController.state.isOpen 驱动显隐。结构为遮罩 + 居中面板两个
// Stack 兄弟节点：
// - 遮罩：全播放器半透明层，点击关闭（PANEL-05）；
// - 面板：GlassContainer(GlassTier.normal) + 标题栏（"设置" + 关闭按钮）。
//
// 持久状态（isOpen/selectedTab/dragOffset）全部由 controller 持有（D-04）；
// 本 widget 仅持有退出动画期间的临时挂载标志，保证 200ms 关闭动画播完再卸载。
//
// Plan 30-02 扩展（D-03/D-05/D-06）：drag session 异步缓存窗口屏幕坐标，
// 每帧用 DisplayInfo.workArea + 缓存坐标做屏幕坐标 clamp；null/异常走对称
// MediaQuery fallback + debugPrint；resize 时 didChangeDependencies 排 post-frame
// re-clamp。保留 RepaintBoundary（D-06）。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../kernel/bridge/display_enumerator.dart';
import '../../shared/apple_curves.dart';
import '../../shared/control_bar_decoration.dart';
import '../../shared/glass_container.dart';
import '../../shared/settings_button.dart';
import '../../theme/tokens.dart';
import 'panel_key_bindings.dart';
import 'settings_panel_controller.dart';
import 'tab_content.dart';
import 'tab_strip.dart';

/// 设置覆盖层壳 — 毛玻璃 + 遮罩 + 标题栏的模态骨架（壳先于内容，tab 内容属 Phase 25）。
///
/// 开/关动画：AnimatedOpacity + AnimatedScale，时长固定 200ms（D-07）；
/// 开启用 [AppleCurves.fullscreenEnter]（ease-out），关闭用
/// [AppleCurves.fullscreenExit]（ease-in）（D-08）。
///
/// 命中安全（T-23-01）：关闭瞬间即 `IgnorePointer(ignoring: true)` 屏蔽命中，
/// 退出动画结束后条件渲染移除整棵壳子树，不存在 opacity=0 仍可命中的窗口。
class SettingsOverlayShell extends StatefulWidget {
  const SettingsOverlayShell({
    super.key,
    required this.controller,
    this.resizing,
    this.displayEnumerator,
    this.windowPositionReader,
  });

  /// 面板控制器 — 提供 isOpen/dragOffset 状态与 close() 生命周期入口.
  final SettingsPanelController controller;

  /// 窗口 resize 信号 — true 时 GlassContainer 跳过 BackdropFilter（防 GPU readback 卡顿）.
  final ValueListenable<bool>? resizing;

  /// 可选 [DisplayEnumerator] 注入 — 提供 [DisplayInfo.workArea] 用于拖拽 clamp（D-03）。
  ///
  /// null 时走对称 [MediaQuery] clamp（兼容现有构造与测试）。生产默认注入
  /// [Win32DisplayAdapter] 属 Plan 30-02（per-session 窗口位置缓存 + FFI fallback）；
  /// 本 Plan 30-01 tracer 仅验证注入路径：fake 注入不对称 workArea 后拖拽停在其边界。
  final DisplayEnumerator? displayEnumerator;

  /// 可选窗口位置读取器 — 拖拽 session 开始时异步缓存窗口屏幕坐标（D-03）.
  ///
  /// 生产默认注入委托 `windowManager.getPosition()`（Plan 30-02）；null 时退回
  /// "窗口充满当前显示器"的 tracer 假设（兼容 30-01 几何，[DisplayInfo.workArea]
  /// 直接作为窗口坐标原点）。缓存值与 workArea 同为屏幕逻辑像素坐标系，用于
  /// 把面板偏移正确转换到屏幕坐标 clamp，避免窗口未充满显示器时的几何漂移。
  final Future<Offset> Function()? windowPositionReader;

  /// 壳根部 key（测试定位用）— 仅打开或退出动画期间存在于树中.
  static const Key shellKey = ValueKey('settings-overlay-shell');

  /// 遮罩 key（测试定位用）.
  static const Key maskKey = ValueKey('settings-overlay-mask');

  /// 标题栏拖拽区 key（测试定位用）.
  static const Key titleBarKey = ValueKey('settings-overlay-titlebar');

  /// 关闭按钮 key（测试定位用）.
  static const Key closeButtonKey = ValueKey('settings-overlay-close');

  /// 面板 sizing box key（测试断言精确尺寸用）.
  static const Key panelKey = ValueKey('settings-overlay-panel');

  /// 底部按钮栏 key（测试定位用）.
  static const Key buttonBarKey = ValueKey('settings-overlay-button-bar');

  /// 开/关动画时长 — 200ms，与 P24 侧边栏 FadeTransition 节奏一致（D-07）.
  static const Duration animationDuration = Duration(milliseconds: 200);

  @override
  State<SettingsOverlayShell> createState() => _SettingsOverlayShellState();
}

class _SettingsOverlayShellState extends State<SettingsOverlayShell> {
  /// 退出动画挂载标志 — isOpen 翻 false 后保持 200ms，让关闭动画播完再卸载命中目标。
  bool _mountedForExit = false;

  /// drag session 缓存的窗口屏幕坐标原点（D-03）— onPanStart 异步 resolve 后填入，
  /// onPanUpdate 用它把面板偏移转换到屏幕坐标做 workArea clamp。null 表示本帧尚未
  /// resolve 或 reader 缺失，退回 workArea 直接作原点的 tracer 路径。
  Offset? _cachedWindowOrigin;

  /// 上次 MediaQuery size — didChangeDependencies 对比，仅尺寸变化时排 post-frame
  /// re-clamp（D-05），避免无谓回调排队。
  Size? _lastMediaSize;

  SettingsPanelController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // 初始即打开的场景（测试先 open 再 pump）直接置为已挂载。
    _mountedForExit = _controller.state.isOpen.value;
    _controller.state.isOpen.addListener(_onIsOpenChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // D-05：MediaQuery 尺寸变化（窗口 resize）时排 post-frame re-clamp。
    // post-frame 等布局完成拿到新面板尺寸再算，避免用旧尺寸 clamp。
    final mediaSize = MediaQuery.sizeOf(context);
    if (_lastMediaSize == mediaSize) return;
    _lastMediaSize = mediaSize;
    _scheduleResizeReclamp();
  }

  /// 排一个 post-frame callback，用最新 MediaQuery + 面板几何重新 clamp 已有 dragOffset。
  ///
  /// 只在 offset 非法时写入，避免无谓 rebuild（D-05）。guarded against stale
  /// callback / disposal：mounted 检查 + 重新读 [MediaQuery.sizeOf] 取最新值，
  /// 即使旧 frame 排的回调在新 build 后执行也用最新几何。
  void _scheduleResizeReclamp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaSize = MediaQuery.sizeOf(context);
      final width = _panelWidth(mediaSize);
      final height = _panelHeight(width);
      final current = _controller.state.dragOffset.value;
      final clamped = _clampDragOffset(
        current,
        mediaSize,
        Size(width, height),
      );
      // 只在 resize 让 offset 非法时写入（D-05）
      if (clamped != current) {
        _controller.state.dragOffset.value = clamped;
      }
    });
  }

  @override
  void dispose() {
    _controller.state.isOpen.removeListener(_onIsOpenChanged);
    super.dispose();
  }

  /// 监听 isOpen：打开时立即挂载；关闭时延迟一个动画周期再卸载。
  void _onIsOpenChanged() {
    final open = _controller.state.isOpen.value;
    if (open) {
      if (!_mountedForExit) setState(() => _mountedForExit = true);
      return;
    }
    // 关闭：延迟 200ms（与关闭动画同长）卸载；期间 IgnorePointer 已屏蔽命中。
    // 若 200ms 内重新打开（isOpen 回 true）则保持挂载，避免闪烁。
    Future.delayed(SettingsOverlayShell.animationDuration, () {
      if (mounted && !_controller.state.isOpen.value && _mountedForExit) {
        setState(() => _mountedForExit = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.state.isOpen,
      builder: (context, open, _) {
        if (!open && !_mountedForExit) {
          // 完全关闭 — 壳不渲染，下层控件恢复全部命中（PANEL-05）。
          return const SizedBox.shrink();
        }
        // D-08：开启用 ease-out（快启慢停），关闭用 ease-in（加速离场）。
        final curve = open
            ? AppleCurves.fullscreenEnter
            : AppleCurves.fullscreenExit;

        return IgnorePointer(
          ignoring: !open,
          child: Stack(
            key: SettingsOverlayShell.shellKey,
            children: [
              // 遮罩层 — 全播放器，点击关闭（PANEL-05）。
              // Tokens 无专用遮罩角色值，沿用旧面板 Colors.black54 遮罩语义。
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: open ? 1.0 : 0.0,
                  duration: SettingsOverlayShell.animationDuration,
                  curve: curve,
                  child: GestureDetector(
                    key: SettingsOverlayShell.maskKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: _controller.close,
                    child: const ColoredBox(color: Colors.black54),
                  ),
                ),
              ),
              // 居中面板 — Scale + Fade + 拖拽位移（PANEL-05 / D-09）。
              ValueListenableBuilder<Offset>(
                valueListenable: _controller.state.dragOffset,
                builder: (context, dragOffset, _) {
                  return Center(
                    child: Transform.translate(
                      offset: dragOffset,
                      child: AnimatedScale(
                        scale: open ? 1.0 : 0.9,
                        duration: SettingsOverlayShell.animationDuration,
                        curve: curve,
                        child: AnimatedOpacity(
                          opacity: open ? 1.0 : 0.0,
                          duration: SettingsOverlayShell.animationDuration,
                          curve: curve,
                          child: _buildPanel(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 面板宽度 — D-04 严格 16:9 公式：width = min(0.5×W, H×16/9).clamp(400, 960)。
  /// 取 screenW×ratio 与 screenH×aspectRatio 的较小者，保证宽高都不超 16:9 容器；
  /// sizing 公式无断点分支（breakpointResponsive 仅驱动 tab-compact 呈现）。
  static double _panelWidth(Size mediaSize) {
    final widthFromRatio = mediaSize.width * Tokens.panelWidthRatio;
    final widthFromHeight = mediaSize.height * Tokens.panelAspectRatio;
    final raw = widthFromRatio < widthFromHeight
        ? widthFromRatio
        : widthFromHeight;
    return raw.clamp(Tokens.panelMinWidth, Tokens.panelMaxWidth);
  }

  /// 面板高度 — D-04：width / panelAspectRatio（即 width × 9/16）。
  static double _panelHeight(double width) => width / Tokens.panelAspectRatio;

  /// 面板 — RepaintBoundary + GlassContainer + 标题栏 + tab bar + 内容区 + Focus 键盘处理。
  ///
  /// 三段式布局（D-07）：标题栏 → 水平 tab bar（40px, bgPanel）→ 内容区（毛玻璃, 16dp padding）。
  /// RepaintBoundary 隔离面板重绘，防止 PlayerScreen 联动刷新（D-07 / D-06）。
  /// 包裹 FocusTraversalGroup + autofocus Focus 实现 D-10 自管键盘作用域。
  Widget _buildPanel(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = _panelWidth(mediaSize);
    final height = _panelHeight(width);
    final isCompact = mediaSize.width < Tokens.breakpointResponsive;
    // 无状态键盘路由 helper — root Focus 的 onKeyEvent 委托给它 (REFAC-01)。
    final keyBindings = SettingsPanelKeyBindings(_controller);

    return RepaintBoundary(
      child: FocusTraversalGroup(
        child: Focus(
          autofocus: true,
          onKeyEvent: keyBindings.handle,
          child: GlassContainer(
            tier: GlassTier.normal,
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            resizing: widget.resizing,
            child: SizedBox(
              key: SettingsOverlayShell.panelKey,
              width: width,
              height: height,
              child: Column(
                children: [
                  _buildTitleBar(mediaSize, Size(width, height)),
                  SettingsTabStrip(
                    selectedTab: _controller.state.selectedTab,
                    onSelect: (i) => _controller.state.selectedTab.value = i,
                    isCompact: isCompact,
                  ),
                  Expanded(
                    child: SettingsTabContent(
                      selectedTab: _controller.state.selectedTab,
                      pending: _controller.pending,
                    ),
                  ),
                  _buildButtonBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部按钮栏 — Cancel / Apply / OK，始终可见（TABS-03/TABS-04）。
  ///
  /// OK：提交待修改值 + 关闭面板；Apply：仅提交不关闭；Cancel：回滚 + 关闭。
  Widget _buildButtonBar() {
    return Container(
      key: SettingsOverlayShell.buttonBarKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      color: Tokens.panelSectionBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SettingsButton(
            label: '取消',
            onTap: () {
              _controller.cancelPending();
              _controller.close();
            },
          ),
          const SizedBox(width: Tokens.spSm),
          SettingsButton(
            label: '应用',
            onTap: () {
              _controller.commitPending();
            },
          ),
          const SizedBox(width: Tokens.spSm),
          SettingsButton(
            label: '确定',
            primary: true,
            onTap: () {
              _controller.commitPending();
              _controller.close();
            },
          ),
        ],
      ),
    );
  }

  /// 标题栏 — 左侧 "设置" 文字 + 右侧关闭按钮（PANEL-04）。
  ///
  /// 标题栏区域支持拖拽（D-09）：onPanStart 异步缓存窗口屏幕坐标（D-03），
  /// onPanUpdate 更新 dragOffset 并 clamp 到显示器 workArea（D-03）。
  ///
  /// Phase 31 D-11：chrome 装饰切换为共享 [ControlBarDecoration.playing]
  /// （4-shadow + controlBarBg + controlBarBorderWhite 边框 + glowOuterRing），
  /// 仅顶部圆角（radiusLg）——与 GlassContainer 外轮廓对齐，段间零圆角防
  /// 阴影接缝（31-RESEARCH Pitfall 1 的 corner-only 缓解）。
  Widget _buildTitleBar(Size mediaSize, Size panelSize) {
    return GestureDetector(
      key: SettingsOverlayShell.titleBarKey,
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _onDragStart(),
      onPanUpdate: (details) => _onDragUpdate(details, mediaSize, panelSize),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
        decoration: ControlBarDecoration.playing(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Tokens.radiusLg),
          ),
        ),
        child: Row(
          children: [
            const Text(
              '设置',
              style: TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontBody,
                fontWeight: Tokens.weightSemiBold,
              ),
            ),
            const Spacer(),
            GlassButton.iconOnly(
              key: SettingsOverlayShell.closeButtonKey,
              icon: Icons.close,
              tooltip: '关闭',
              iconSize: Tokens.iconMd,
              onPressed: _controller.close,
            ),
          ],
        ),
      ),
    );
  }

  /// drag session 开始 — 异步缓存窗口屏幕坐标原点（D-03）。
  ///
  /// side effect: 启动异步 Future + 写实例状态 [_cachedWindowOrigin]；不阻塞手势。
  /// [windowPositionReader] 返回 Future（windowManager.getPosition() 异步）；
  /// resolve 后写入 [_cachedWindowOrigin] 供后续 onPanUpdate 用。reader 缺失或
  /// 抛异常时保持 null，_clampDragOffset 会走 workArea 直接作原点的 tracer 路径。
  void _onDragStart() {
    final reader = widget.windowPositionReader;
    if (reader == null) {
      _cachedWindowOrigin = null;
      return;
    }
    // 异步缓存：失败时 debugPrint + 置 null（fallback 路径处理）
    reader().then((origin) {
      if (mounted) _cachedWindowOrigin = origin;
    }).catchError((Object error, StackTrace stack) {
      debugPrint('[SettingsOverlayShell] windowPositionReader failed: '
          '$error\n$stack');
      if (mounted) _cachedWindowOrigin = null;
    });
  }

  /// 拖拽更新 — clamp dragOffset 到显示边界（D-03 / D-09 / T-23-03）。
  ///
  /// 优先用注入 [DisplayEnumerator] 的 [DisplayInfo.workArea] + 缓存窗口原点
  /// 做屏幕坐标 clamp；无注入、getCurrentDisplay() 返回 null/抛异常、或 workArea
  /// 比面板小时退回对称 [MediaQuery] clamp（面板不拖出播放器窗口）。
  void _onDragUpdate(
    DragUpdateDetails details,
    Size mediaSize,
    Size panelSize,
  ) {
    final current = _controller.state.dragOffset.value;
    final next = current + details.delta;
    _controller.state.dragOffset.value = _clampDragOffset(
      next,
      mediaSize,
      panelSize,
    );
  }

  /// 计算约束后的 dragOffset — 优先 workArea + 缓存原点（D-03），否则对称 clamp。
  ///
  /// 两条 workArea 路径：
  /// - 有 [_cachedWindowOrigin]：屏幕坐标正确转换（windowOrigin + baseLeft + dx
  ///   映射到 workArea 边界），适用窗口未充满显示器的真实多显示器场景。
  /// - 无 [_cachedWindowOrigin]（reader 缺失/未 resolve/失败）：退回 30-01 tracer
  ///   路径，假设窗口充满显示器（workArea 直接作原点），几何在单显示器下仍正确。
  ///
  /// 异常路径：注入的 DisplayEnumerator 实现可能不内部异常安全，shell 层 try/catch
  /// 保证可用性 + debugPrint 诊断，退回对称 clamp（plan 30-02 D-03 fallback）。
  Offset _clampDragOffset(Offset next, Size mediaSize, Size panelSize) {
    // D-03: 同步解析当前显示器，有 workArea 且足够大时用它 clamp
    final DisplayInfo? info;
    try {
      info = widget.displayEnumerator?.getCurrentDisplay();
    } catch (e, st) {
      // 注入的 enumerator 实现可能抛异常 — 不让它崩溃手势，debugPrint + 对称 fallback
      debugPrint('[SettingsOverlayShell] getCurrentDisplay failed: $e\n$st');
      return _symmetricClamp(next, mediaSize, panelSize);
    }
    if (info != null) {
      final workArea = info.workArea;
      if (workArea.width >= panelSize.width &&
          workArea.height >= panelSize.height) {
        final origin = _cachedWindowOrigin;
        if (origin != null) {
          return _clampToWorkAreaWithOrigin(
            next,
            mediaSize,
            panelSize,
            workArea,
            origin,
          );
        }
        return _clampToWorkArea(next, mediaSize, panelSize, workArea);
      }
    }
    return _symmetricClamp(next, mediaSize, panelSize);
  }

  /// 对称 [MediaQuery] clamp — 面板居中时 dragOffset=0，最大偏移=(窗口-面板)/2.
  /// 负值表示面板大于窗口，此时 clamp 到 0 禁止拖拽。
  static Offset _symmetricClamp(Offset next, Size mediaSize, Size panelSize) {
    final maxX = ((mediaSize.width - panelSize.width) / 2).clamp(
      0.0,
      double.infinity,
    );
    final maxY = ((mediaSize.height - panelSize.height) / 2).clamp(
      0.0,
      double.infinity,
    );
    return Offset(
      next.dx.clamp(-maxX, maxX),
      next.dy.clamp(-maxY, maxY),
    );
  }

  /// 用 [DisplayInfo.workArea] clamp dragOffset（D-03 tracer 路径）。
  ///
  /// 假设窗口充满当前显示器（workArea.left 直接作窗口原点 x）。适用单显示器
  /// 或窗口最大化场景；多显示器窗口未充满时用 [_clampToWorkAreaWithOrigin]。
  /// 面板居中时 dragOffset=0，左上角 = (baseLeft, baseTop)。约束：左上角 >=
  /// workArea 左上角，右下角 <= workArea 右下角。调用方已保证 workArea >= panelSize。
  static Offset _clampToWorkArea(
    Offset candidate,
    Size mediaSize,
    Size panelSize,
    Rect workArea,
  ) {
    final baseLeft = (mediaSize.width - panelSize.width) / 2;
    final baseTop = (mediaSize.height - panelSize.height) / 2;
    // 面板左边缘 = baseLeft + dx >= workArea.left → dx >= workArea.left - baseLeft
    // 面板右边缘 = baseLeft + dx + panelW <= workArea.right → dx <= workArea.right - baseLeft - panelW
    final minX = workArea.left - baseLeft;
    final maxX = workArea.right - baseLeft - panelSize.width;
    final minY = workArea.top - baseTop;
    final maxY = workArea.bottom - baseTop - panelSize.height;
    return Offset(
      candidate.dx.clamp(minX, maxX),
      candidate.dy.clamp(minY, maxY),
    );
  }

  /// 用 workArea + 缓存窗口原点做屏幕坐标 clamp（D-03 production 路径）。
  ///
  /// 几何：面板左上角屏幕坐标 = windowOrigin + (baseLeft + dx, baseTop + dy)。
  /// 约束 面板左上 >= workArea.left 且 面板右下 <= workArea.right/bottom：
  ///   dx >= workArea.left  - windowOrigin.x - baseLeft
  ///   dx <= workArea.right - windowOrigin.x - baseLeft - panelW
  /// （y 同理）。调用方已保证 workArea >= panelSize 且 origin != null。
  static Offset _clampToWorkAreaWithOrigin(
    Offset candidate,
    Size mediaSize,
    Size panelSize,
    Rect workArea,
    Offset windowOrigin,
  ) {
    final baseLeft = (mediaSize.width - panelSize.width) / 2;
    final baseTop = (mediaSize.height - panelSize.height) / 2;
    final minX = workArea.left - windowOrigin.dx - baseLeft;
    final maxX = workArea.right - windowOrigin.dx - baseLeft - panelSize.width;
    final minY = workArea.top - windowOrigin.dy - baseTop;
    final maxY = workArea.bottom - windowOrigin.dy - baseTop - panelSize.height;
    return Offset(
      candidate.dx.clamp(minX, maxX),
      candidate.dy.clamp(minY, maxY),
    );
  }
}
