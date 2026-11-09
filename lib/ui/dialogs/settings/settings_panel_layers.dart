part of 'settings_panel.dart';

/// L0 tag 层与 L1 内容层的叠放 — 层级切换的纯渲染层动画。
///
/// 两层子树由宿主以 widget identity 缓存后传入（[tagLayer]/[contentLayer]），
/// 动画帧只换 Opacity/Transform/Offstage，缓存内部零重建.
class _LayerStack extends StatelessWidget {
  const _LayerStack({
    required this.visible,
    required this.level,
    required this.motion,
    required this.tagLayer,
    required this.contentLayer,
  });

  final bool visible;
  final _PanelLevel level;
  final _PanelMotion motion;
  final Widget tagLayer;
  final Widget contentLayer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TagLayerSlot(
          visible: visible,
          level: level,
          ease: motion.layerEase,
          child: tagLayer,
        ),
        _ContentLayerSlot(
          visible: visible,
          level: level,
          motion: motion,
          child: contentLayer,
        ),
      ],
    );
  }
}

/// L0 tag 层槽位 — 进入 L1 后退（左移+微缩）淡出至完全消失并让出命中（D3）；
/// 退出 L1 反向回来。TickerMode 在隐藏/L1 时静音跑马灯与 chip 隐式动画.
class _TagLayerSlot extends StatelessWidget {
  const _TagLayerSlot({
    required this.visible,
    required this.level,
    required this.ease,
    required this.child,
  });

  final bool visible;
  final _PanelLevel level;
  final Animation<double> ease;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isTags = level == _PanelLevel.tags;
    return TickerMode(
      enabled: visible && isTags,
      child: IgnorePointer(
        ignoring: !isTags,
        child: AnimatedBuilder(
          animation: ease,
          // child 走缓存 (v0.0.8.2) — 动画帧只换 Opacity/Transform 矩阵.
          child: SecondarySurfaceOwner(
            visible: visible && isTags,
            child: child,
          ),
          builder: (context, child) {
            final t = ease.value;
            return Opacity(
              opacity: 1.0 - t,
              child: Transform.translate(
                offset: Offset(-Tokens.settingsLayerSlideOffset * t, 0),
                child: Transform.scale(
                  scale: 1.0 - Tokens.settingsLayerBackScaleDelta * t,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// L1 内容层槽位 — 从右滑入覆盖标题行以下区域；L0 静止期 Offstage
/// （不 paint/不命中/语义不可见），滑出动画期间保持挂载以呈现退出动效。
/// 内容层走 child: 参数 — 动画帧只换 Offstage 开关，分区内容子树零重建.
class _ContentLayerSlot extends StatelessWidget {
  const _ContentLayerSlot({
    required this.visible,
    required this.level,
    required this.motion,
    required this.child,
  });

  final bool visible;
  final _PanelLevel level;
  final _PanelMotion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isTags = level == _PanelLevel.tags;
    return AnimatedBuilder(
      animation: motion.layerController,
      child: IgnorePointer(
        ignoring: isTags,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(motion.layerEase),
          // 缓存同 L0 — level 翻转不重建内容子树, 只有 _selected
          // 变化 (分区切换) 才失效重建.
          child: SecondarySurfaceOwner(
            visible: visible && !isTags,
            child: child,
          ),
        ),
      ),
      builder: (_, child) => Offstage(
        offstage: isTags && !motion.layerController.isAnimating,
        child: child,
      ),
    );
  }
}

/// L0 tag 层 — 竖排分区入口，撑满内容区（水平对称居中），
/// 宽度随面板/窗口响应；摘要跑马灯的滚动空间随之联动.
class _TagLayer extends StatelessWidget {
  const _TagLayer({required this.selected, required this.onTapTab});

  final _SettingsTab selected;

  /// 点击任意 enabled tag — 宿主一步直达选中并进入内容层.
  final ValueChanged<_SettingsTab> onTapTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tab in _SettingsTab.values)
            _SettingsTabChip(
              tab: tab,
              selected: selected == tab,
              enabled: _enabledTabs.contains(tab),
              onTap: () => onTapTab(tab),
            ),
        ],
      ),
    );
  }
}

/// L1 内容层 — 分区内容（方向性滑动切换）.
class _ContentLayer extends StatelessWidget {
  const _ContentLayer({
    required this.selected,
    required this.services,
    required this.generalEligible,
    required this.rowsFocusNode,
    required this.audioRowsFocusNode,
    required this.scrollFor,
    required this.onScrolled,
  });

  final _SettingsTab selected;
  final SettingsServicesBundle? services;
  final ValueNotifier<bool> generalEligible;
  final FocusNode rowsFocusNode;
  final FocusNode audioRowsFocusNode;
  final ScrollController Function(String section) scrollFor;
  final ValueChanged<double> onScrolled;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: Tokens.durationNormal),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            // 顶部对齐 — 分区内容高度不同时切换不跳中.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: _transition,
            child: KeyedSubtree(
              key: ValueKey(selected),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _onScroll(context, notification),
                child: _TabContent(
                  tab: selected,
                  services: services,
                  generalEligible: generalEligible,
                  rowsFocusNode: rowsFocusNode,
                  audioRowsFocusNode: audioRowsFocusNode,
                  scrollFor: scrollFor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 方向性滑动 — 进入者从右侧滑入, 退出者向左滑出（恒正向:
  /// L1 内只剩 → 切下一分区, ← 已改为返回 tag 层）.
  Widget _transition(Widget child, Animation<double> animation) {
    final isIncoming = child.key == ValueKey(selected);
    final offset = isIncoming ? const Offset(1, 0) : const Offset(-1, 0);
    // RepaintBoundary — 分区切换 150ms 内出入双子树并存, 各自
    // 隔离重绘区域 (layout 双算不可避免, paint 减半).
    return RepaintBoundary(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Only the active route writes; a hidden window route may clamp
  /// its shorter viewport while following fullscreen presentation.
  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (ModalRoute.of(context)?.isCurrent != false) {
      onScrolled(notification.metrics.pixels);
    }
    return false;
  }
}

/// 分区内容 switch — 内容组件零改动复用（拓展点：服务启用后自动获得
/// L1 通道）; 灰显防御分支返回空视图而非伪造内容.
class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.services,
    required this.generalEligible,
    required this.rowsFocusNode,
    required this.audioRowsFocusNode,
    required this.scrollFor,
  });

  final _SettingsTab tab;
  final SettingsServicesBundle? services;
  final ValueNotifier<bool> generalEligible;
  final FocusNode rowsFocusNode;
  final FocusNode audioRowsFocusNode;
  final ScrollController Function(String section) scrollFor;

  @override
  Widget build(BuildContext context) {
    // 局部非空绑定 + guard 分支取代 `!` — 缺服务的分区回落空视图.
    final videoProcessing = services?.videoProcessing;
    final settings = services?.settings;
    return switch (tab) {
      _SettingsTab.general => SecondarySurfaceOwner(
        visible: true,
        eligibility: generalEligible,
        child: GeneralSettingsContent(
          settings: settings,
          rowsFocusNode: rowsFocusNode,
          scrollController: scrollFor('general'),
        ),
      ),
      _SettingsTab.video when videoProcessing != null => VideoSettingsContent(
        videoProcessing: videoProcessing,
        settings: settings,
        scrollController: scrollFor('video'),
      ),
      _SettingsTab.audio when settings != null => AudioSettingsContent(
        settings: settings,
        rowsFocusNode: audioRowsFocusNode,
        scrollController: scrollFor('audio'),
      ),
      _SettingsTab.video || _SettingsTab.audio => const SizedBox.shrink(),
      _SettingsTab.about => AboutContent(scrollController: scrollFor('about')),
    };
  }
}
