import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 自动隐藏控制器 — 管理控制栏可见性、淡入淡出动画、自动隐藏定时器、鼠标悬停节流
///
/// 从 ControlsOverlay 提取，独立可测试。
///
/// 路径B阶段2:仅接收 [ValueNotifier<bool>] `isPlaying` — 非 playing 永显,
/// 仅 playing 自动隐藏。归约原 `MediaState` 多状态策略(opening/paused/completed
/// /error 均视为非 playing 永显),与原策略一致。原 idle 专清 `_activeInteractionCount`
/// 语义扩展为「任意 false 转换都清」(更保守,无副作用 — 新媒体/暂停/出错中断旧手势
/// 序列都需清计数,避免下一次播放永久不自动隐藏)。
class AutoHideController {
  AutoHideController({
    required TickerProvider vsync,
    required ValueNotifier<bool> isPlaying,
    required bool isFullscreen,
    ValueNotifier<int>? popupCloseNotifier,
  }) : _isPlaying = isPlaying,
       _isFullscreen = isFullscreen,
       _popupCloseNotifier = popupCloseNotifier {
    _animController = AnimationController(
      vsync: vsync,
      // 对齐 media_kit 原生 150ms 控件淡入淡出(原 durationFade=400ms 偏慢)
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
      value: 1,
    );
    // D-02: easeInOut 对称曲线 — 出现和消失速度一致
    _opacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // fade-out 完成后立即关闭 hit test，避免透明 overlay 拦截点击
    _animController.addStatusListener(_onAnimStatus);
    // 阶段2:监听 isPlaying 自动响应(替代原 onEngineStateChanged 手动调用)。
    // 调用方只需更新 isPlaying notifier,本控制器自行触发 _onPlayingChanged。
    _isPlaying.addListener(_onPlayingChanged);
  }

  final ValueNotifier<bool> _isPlaying;
  final ValueNotifier<int>? _popupCloseNotifier;
  bool _isFullscreen;
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  bool _hovering = false;
  bool _resizing = false;

  /// 正在进行的子控件交互数量。
  ///
  /// 进度条、音量滑块和 popup 可能重叠；使用计数而不是单个 bool，确保任一
  /// 交互仍活跃时不会过早恢复自动隐藏。
  int _activeInteractionCount = 0;
  Timer? _hideTimer;
  DateTime _lastHoverTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _hoverThrottle = Duration(milliseconds: 100);

  /// 可见性通知器（用于 ValueListenableBuilder 局部重建）
  final ValueNotifier<bool> visible = ValueNotifier(true);

  /// 淡入淡出动画（用于 FadeTransition）
  Animation<double> get opacity => _opacity;

  /// 是否正在悬停
  bool get isHovering => _hovering;

  /// 更新全屏状态（窗口/全屏切换时调用）
  set isFullscreen(bool value) {
    _isFullscreen = value;
    scheduleHide();
  }

  Duration get _hideDelay => _isFullscreen
      ? const Duration(seconds: Tokens.hideDelayFullscreen)
      : const Duration(seconds: Tokens.hideDelayWindowed);

  /// 显示控制栏（带动画）
  void show() {
    if (!visible.value) {
      visible.value = true;
      _animController.forward();
    }
  }

  /// 隐藏控制栏（带动画，非 playing 时不隐藏）
  ///
  /// 阶段2:归约自原 `if (engineState == idle) return` — 非 playing 永显,
  /// 单击非 playing 状态不再隐藏控件(与永显策略一致,消除原 paused 单击隐藏
  /// 的不一致)。
  void hide() {
    if (!_isPlaying.value) return;
    if (visible.value) {
      _popupCloseNotifier?.value++;
      _animController.reverse();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      visible.value = false;
    }
  }

  /// 取消旧 Timer 再设新的，避免多次鼠标移动导致 Timer 堆积。
  ///
  /// 只有 playing 状态、未 resize 且没有活跃子控件交互时才允许自动隐藏；所有
  /// 调用方均经过此处，避免窗口状态变化绕开交互会话保护。
  void scheduleHide() {
    _hideTimer?.cancel();
    if (!_isPlaying.value || _resizing || _activeInteractionCount > 0) {
      return;
    }
    _hideTimer = Timer(_hideDelay, () {
      // 阶段3问题3修复:去掉 !_hovering 检查 — 对齐 media_kit 原生「静止 3s 隐藏」。
      // MouseRegion 整区覆盖(含 ControlBar),鼠标在 Video 内 _hovering 恒 true,
      // 原 !_hovering 检查致静止永不隐藏。整区 MouseRegion 下 onExit 不会误触
      // (ControlsOverlay 时期该检查防的「移到 ControlBar 误 onExit」已不成立)。
      // _activeInteractionCount 仍保护拖拽进度条/滑块交互期间不隐藏。
      if (_activeInteractionCount == 0) hide();
    });
  }

  /// 更新 resize 状态 — resize 期间冻结自动隐藏逻辑
  set resizing(bool value) {
    _resizing = value;
    if (value) {
      _hideTimer?.cancel();
    } else {
      scheduleHide();
    }
  }

  /// 鼠标移动（节流 100ms）
  ///
  /// 阶段2:非 playing 直接 return(原 idle return 扩展)。非 playing 永显,
  /// show() 本就是 no-op,故无实质行为变化。
  void onMouseMove() {
    if (!_isPlaying.value || _resizing) return;
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottle) return;
    _lastHoverTime = now;
    show();
    scheduleHide();
  }

  /// 鼠标进入
  void onMouseEnter() {
    _hovering = true;
    show();
    scheduleHide();
  }

  /// 鼠标离开
  ///
  /// 阶段2:仅 playing 调度隐藏(原 `!= idle` 调度,但 scheduleHide 内部非 playing
  /// 本就 no-op,故等价)。
  void onMouseExit() {
    _hovering = false;
    if (_isPlaying.value) scheduleHide();
  }

  /// isPlaying 变化处理 — 由 [_isPlaying] listener 自动触发。
  ///
  /// 状态策略(对齐 media_kit 原生 + 增强,归约自原 MediaState 多状态):
  /// - playing(true): show + scheduleHide(唯一自动隐藏状态)
  /// - 非 playing(false): 清交互计数 + cancel timer + 永显(覆盖原 idle/opening
  ///   /paused/completed/error;idle 专清计数语义扩展为任意 false 转换都清)
  void _onPlayingChanged() {
    if (_isPlaying.value) {
      show();
      // 无论当前是否可见，始终重置隐藏定时器
      scheduleHide();
      return;
    }
    // 非 playing:清计数(中断旧手势序列)+ cancel + 永显
    _activeInteractionCount = 0;
    _hideTimer?.cancel();
    if (!visible.value) {
      show();
    }
  }

  /// 开始一个子控件交互会话，并冻结 playing 状态的自动隐藏。
  ///
  /// UI 子组件只报告交互边界，不自行维护隐藏 Timer，避免拖拽、悬停和 popup
  /// 的异步结束顺序造成控制栏提前消失。非 playing 没有可自动隐藏的控件,保持 no-op。
  void onInteractionStart() {
    if (!_isPlaying.value) return;
    _activeInteractionCount++;
    show();
    _hideTimer?.cancel();
  }

  /// 结束一个子控件交互会话；最后一个会话结束后恢复既有隐藏策略。
  void onInteractionEnd() {
    if (!_isPlaying.value || _activeInteractionCount == 0) {
      return;
    }
    _activeInteractionCount--;
    if (_activeInteractionCount == 0 && !_resizing) scheduleHide();
  }

  /// 用户开始拖动进度条 — 显示控件并冻结隐藏计时(seek 期间不隐藏).
  ///
  /// 对齐 media_kit 原生 onSeekStart，并复用统一交互会话以保证其他子控件
  /// 同时交互时也不会提前恢复自动隐藏。
  void onSeekStart() => onInteractionStart();

  /// 用户结束拖动进度条 — 在最后一个活跃交互结束后重启隐藏计时。
  void onSeekEnd() => onInteractionEnd();

  /// 初始状态：非 playing 时永久显示，否则启动自动隐藏
  void init() {
    if (!_isPlaying.value) {
      visible.value = true;
      _animController.value = 1;
    } else {
      scheduleHide();
    }
  }

  /// 清理资源
  void dispose() {
    _isPlaying.removeListener(_onPlayingChanged);
    _hideTimer?.cancel();
    _animController.removeStatusListener(_onAnimStatus);
    visible.dispose();
    _animController.dispose();
  }
}
