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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../kernel/bridge/display_enumerator.dart';
import '../../shared/apple_curves.dart';
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

  SettingsPanelController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // 初始即打开的场景（测试先 open 再 pump）直接置为已挂载。
    _mountedForExit = _controller.state.isOpen.value;
    _controller.state.isOpen.addListener(_onIsOpenChanged);
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
  /// RepaintBoundary 隔离面板重绘，防止 PlayerScreen 联动刷新（D-07）。
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
      color: Tokens.bgGlass,
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
  /// 标题栏区域支持拖拽（D-09）：onPanUpdate 更新 dragOffset，
  /// clamp 到 MediaQuery 窗口边界减去面板尺寸的一半。
  Widget _buildTitleBar(Size mediaSize, Size panelSize) {
    return GestureDetector(
      key: SettingsOverlayShell.titleBarKey,
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) => _onDragUpdate(details, mediaSize, panelSize),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
        color: Tokens.bgGlass,
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

  /// 拖拽更新 — clamp dragOffset 到显示边界（D-03 / D-09 / T-23-03）。
  ///
  /// 优先用注入 [DisplayEnumerator] 的 [DisplayInfo.workArea]（显示器可用区域，
  /// 排除任务栏）clamp；无注入、getCurrentDisplay() 返回 null、或 workArea 比面板小
  /// 时退回对称 [MediaQuery] clamp（面板不拖出播放器窗口）。
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

  /// 计算约束后的 dragOffset — 优先 workArea（D-03），否则对称 MediaQuery clamp。
  ///
  /// workArea 路径假设窗口充满主显示器（tracer 级别；per-session 窗口位置缓存、
  /// 多显示器跨屏、resize 重新夹具属 Plan 30-02 production hardening）。
  Offset _clampDragOffset(Offset next, Size mediaSize, Size panelSize) {
    // D-03: 同步解析当前显示器，有 workArea 且足够大时用它 clamp
    final info = widget.displayEnumerator?.getCurrentDisplay();
    if (info != null) {
      final workArea = info.workArea;
      if (workArea.width >= panelSize.width &&
          workArea.height >= panelSize.height) {
        return _clampToWorkArea(next, mediaSize, panelSize, workArea);
      }
    }
    // 对称 clamp — 面板居中时 dragOffset=0，最大偏移 = (窗口-面板)/2
    // 负值表示面板大于窗口，此时 clamp 到 0 禁止拖拽
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

  /// 用 [DisplayInfo.workArea] clamp dragOffset（D-03）。
  ///
  /// 面板居中时 dragOffset=0，左上角 = (baseLeft, baseTop)。有 offset 时
  /// 左上角 = (baseLeft + dx, baseTop + dy)。约束：左上角 >= workArea 左上角，
  /// 右下角 <= workArea 右下角。调用方已保证 workArea >= panelSize。
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
}
