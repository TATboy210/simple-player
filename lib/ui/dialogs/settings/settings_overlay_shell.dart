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
import 'package:flutter/services.dart';

import '../../shared/apple_curves.dart';
import '../../shared/glass_container.dart';
import '../../shared/settings_button.dart';
import '../../theme/tokens.dart';
import '_settings_nav_item.dart';
import 'settings_panel_controller.dart';

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
  });

  /// 面板控制器 — 提供 isOpen/dragOffset 状态与 close() 生命周期入口.
  final SettingsPanelController controller;

  /// 窗口 resize 信号 — true 时 GlassContainer 跳过 BackdropFilter（防 GPU readback 卡顿）.
  final ValueListenable<bool>? resizing;

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

  /// 面板宽度比例 — 50% 窗口宽度（clamp 上限 80%）.
  static const double panelWidthRatio = 0.5;

  /// 面板高度比例 — 50% 窗口高度（clamp 上限 80%）.
  static const double panelHeightRatio = 0.5;

  @override
  State<SettingsOverlayShell> createState() => _SettingsOverlayShellState();
}

class _SettingsOverlayShellState extends State<SettingsOverlayShell> {
  /// 退出动画挂载标志 — isOpen 翻 false 后保持 200ms，让关闭动画播完再卸载命中目标。
  bool _mountedForExit = false;

  SettingsPanelController get _controller => widget.controller;

  /// 7 个 tab 的图标（对应 General/EQ/Audio/Video/Shortcuts/About/Performance）。
  static const _tabIcons = [
    Icons.tune,
    Icons.equalizer,
    Icons.headphones,
    Icons.videocam,
    Icons.keyboard,
    Icons.info_outline,
    Icons.speed,
  ];

  /// 7 个 tab 的标签文字（Phase 25 可升级为 l10n）。
  static const _tabLabels = [
    '通用',
    '均衡器',
    '音频',
    '视频',
    '快捷键',
    '关于',
    '性能',
  ];

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

  /// 计算面板尺寸 — 50% 窗口宽高，clamp 上限 80%（PANEL-07）。
  ///
  /// 保持 double 精度，不做 ceil/floor/truncation。
  static Size _panelSize(Size mediaSize) => Size(
    _clampDimension(mediaSize.width, SettingsOverlayShell.panelWidthRatio),
    _clampDimension(mediaSize.height, SettingsOverlayShell.panelHeightRatio),
  );

  /// 单轴尺寸约束 — ratio × 窗口尺寸，clamp 到 80% 上限。
  static double _clampDimension(double mediaExtent, double ratio) =>
      (mediaExtent * ratio).clamp(0, mediaExtent * 0.8);

  /// 面板 — GlassContainer(GlassTier.normal) + 标题栏 + tab bar + 内容区 + Focus 键盘处理。
  ///
  /// 三段式布局（D-07）：标题栏 → 水平 tab bar（40px, bgPanel）→ 内容区（毛玻璃, 16dp padding）。
  /// 包裹 FocusTraversalGroup + autofocus Focus 实现 D-10 自管键盘作用域。
  Widget _buildPanel(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final panelSize = _panelSize(mediaSize);

    return FocusTraversalGroup(
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GlassContainer(
          tier: GlassTier.normal,
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          resizing: widget.resizing,
          child: SizedBox(
            key: SettingsOverlayShell.panelKey,
            width: panelSize.width,
            height: panelSize.height,
            child: Column(
              children: [
                _buildTitleBar(mediaSize, panelSize),
                _buildTabBar(),
                Expanded(child: _buildContent()),
                _buildButtonBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 水平 tab bar — 64px 高，bgGlass 半透明背板与标题栏统一（D-07/D-08）。
  ///
  /// 7 个等宽 [SettingsNavItem] 横排，selectedTab 驱动高亮。
  Widget _buildTabBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _controller.state.selectedTab,
      builder: (context, selectedIndex, _) {
        return Container(
          height: 64,
          color: Tokens.bgGlass,
          child: Row(
            children: List.generate(_tabIcons.length, (i) {
              return Expanded(
                child: SettingsNavItem(
                  icon: _tabIcons[i],
                  label: _tabLabels[i],
                  selected: selectedIndex == i,
                  onTap: () => _controller.state.selectedTab.value = i,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// 内容区 — bgPanel 背板 + IndexedStack 保持 7 个 tab 存活 + TweenAnimationBuilder 淡入淡出（D-01/D-02）。
  ///
  /// 每个 tab 包裹 `TweenAnimationBuilder<double>`，selectedTab 变化时自动
  /// 触发 200ms opacity 过渡。内容区四周 16dp padding（D-10）。
  Widget _buildContent() {
    return ValueListenableBuilder<int>(
      valueListenable: _controller.state.selectedTab,
      builder: (context, selectedIndex, _) {
        return ColoredBox(
          color: Tokens.bgPanel,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.spMd),
            child: IndexedStack(
              index: selectedIndex,
              children: List.generate(_tabLabels.length, (i) {
                return TweenAnimationBuilder<double>(
                  // 目标 opacity：选中 1.0，未选中 0.0
                  tween: Tween<double>(end: i == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) {
                    return Opacity(opacity: opacity, child: child);
                  },
                  // 占位内容 — Phase 25 替换为真实 tab 内容
                  child: Center(
                    child: Text(
                      _tabLabels[i],
                      style: const TextStyle(
                        color: Tokens.textSecondary,
                        fontSize: Tokens.fontBody,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
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

  /// 键盘/手柄事件处理 — ESC/B 关面板，← → 切换 tab，LB/RB 循环 tab（D-04/D-05/D-06）。
  ///
  /// 面板打开时事件由 Focus subtree 消费（返回 handled），不冒泡到
  /// KeyboardHandler（避免触发 seek ±5s）。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ESC/B — 关面板（PANEL-06）
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyB) {
      _controller.close();
      return KeyEventResult.handled;
    }

    // Arrow Left — 切换到上一个 tab（D-04）
    if (key == LogicalKeyboardKey.arrowLeft) {
      _controller.prevTab();
      return KeyEventResult.handled;
    }

    // Arrow Right — 切换到下一个 tab（D-04）
    if (key == LogicalKeyboardKey.arrowRight) {
      _controller.nextTab();
      return KeyEventResult.handled;
    }

    // Gamepad Left Shoulder — 切换到上一个 tab（D-05）
    if (_isLeftShoulder(key)) {
      _controller.prevTab();
      return KeyEventResult.handled;
    }

    // Gamepad Right Shoulder — 切换到下一个 tab（D-05）
    if (_isRightShoulder(key)) {
      _controller.nextTab();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 左肩键检测 — Windows 映射 gameButton13，跨平台也检查 gameButtonLeft1。
  static bool _isLeftShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton13 ||
      key == LogicalKeyboardKey.gameButtonLeft1;

  /// 右肩键检测 — Windows 映射 gameButton12，跨平台也检查 gameButtonRight1。
  static bool _isRightShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton12 ||
      key == LogicalKeyboardKey.gameButtonRight1;

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

  /// 拖拽更新 — clamp dragOffset 到窗口边界（D-09 / T-23-03）。
  ///
  /// maxX/maxY = (窗口尺寸 - 面板尺寸) / 2，保证面板不拖出播放器窗口。
  void _onDragUpdate(
    DragUpdateDetails details,
    Size mediaSize,
    Size panelSize,
  ) {
    final current = _controller.state.dragOffset.value;
    final next = current + details.delta;
    // 面板居中时 dragOffset=0，最大偏移 = (窗口-面板)/2
    final maxX = (mediaSize.width - panelSize.width) / 2;
    final maxY = (mediaSize.height - panelSize.height) / 2;
    _controller.state.dragOffset.value = Offset(
      next.dx.clamp(-maxX, maxX),
      next.dy.clamp(-maxY, maxY),
    );
  }
}
