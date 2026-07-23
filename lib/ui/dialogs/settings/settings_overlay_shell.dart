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

import '../../shared/apple_curves.dart';
import '../../shared/glass_container.dart';
import '../../theme/tokens.dart';
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

  /// 开/关动画时长 — 200ms，与 P24 侧边栏 FadeTransition 节奏一致（D-07）.
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// 面板基础宽度 — PANEL-07：min(500, 窗口宽 × 0.8).
  static const double basePanelWidth = 500.0;

  /// 面板基础高度 — PANEL-07：min(400, 窗口高 × 0.8).
  static const double basePanelHeight = 400.0;

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
              // 居中面板 — Scale + Fade（PANEL-05）。
              Center(
                child: AnimatedScale(
                  scale: open ? 1.0 : 0.9,
                  duration: SettingsOverlayShell.animationDuration,
                  curve: curve,
                  child: AnimatedOpacity(
                    opacity: open ? 1.0 : 0.0,
                    duration: SettingsOverlayShell.animationDuration,
                    curve: curve,
                    child: _buildPanel(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 面板 — GlassContainer(GlassTier.normal) + 标题栏；拦截自身区域点击，
  /// 防止落在面板空白处的点击穿透到遮罩误关面板。
  Widget _buildPanel() {
    return GestureDetector(
      // opaque：面板空白区（无子命中目标处）也拦截，不穿透到下层遮罩。
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: GlassContainer(
        tier: GlassTier.normal,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        resizing: widget.resizing,
        child: SizedBox(
          key: SettingsOverlayShell.panelKey,
          width: SettingsOverlayShell.basePanelWidth,
          height: SettingsOverlayShell.basePanelHeight,
          child: Column(
            children: [
              _buildTitleBar(),
              // Phase 25 挂入 tab 内容；壳阶段仅占位撑开面板。
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏 — 左侧 "设置" 文字 + 右侧关闭按钮（PANEL-04）。
  Widget _buildTitleBar() {
    return Container(
      key: SettingsOverlayShell.titleBarKey,
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
    );
  }
}
