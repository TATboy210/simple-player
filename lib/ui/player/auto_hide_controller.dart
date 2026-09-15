import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 自动隐藏控制器 — 管理控制栏可见性、淡入淡出动画、自动隐藏定时器、鼠标悬停节流
///
/// 控制栏自动隐藏逻辑，独立可测试。
///
/// v0.0.5 对齐 media_kit 原生交互 (用户裁决: 原生优先): 隐藏与播放状态
/// **无关** — 静置 (hover 离开/不响应区) 计时到点即隐藏, 暂停时同样隐藏
/// (media_kit material_desktop.dart onHover/onEnter 的 controlsHoverDuration
/// 语义)。在此基础上的项目层优化:
/// - [modalOpen]: 模态窗口 (设置/菜单) 开启期间冻结隐藏计时, 关窗重新计时
/// - [_activeInteractionCount]: 进度条/滑块拖拽等交互会话保持显示
/// - resizing 冻结; hover 节流; popup 关闭通知
class AutoHideController {
  AutoHideController({
    required TickerProvider vsync,
    required this._isPlaying,
    required this._isFullscreen,
    this._popupCloseNotifier,
  }) {
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
    // 监听 isPlaying — 状态切换瞬间显示控制栏并重启计时 (对齐原生:
    // 暂停/恢复都会唤起控件, 之后静置照常隐藏).
    _isPlaying.addListener(_onPlayingChanged);
  }

  final ValueNotifier<bool> _isPlaying;
  final ValueNotifier<int>? _popupCloseNotifier;
  bool _isFullscreen;
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  bool _hovering = false;
  bool _resizing = false;
  bool _modalOpen = false;
  bool _pinned = false;

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

  /// 显示控制栏（带动画）。
  ///
  /// 即使 [visible] 已为 true，也要调用 forward：自动淡出中的暂停事件必须
  /// 反转尚未结束的 reverse animation，避免 dismissed 回调随后错误隐藏非播放控件。
  void show() {
    if (!visible.value) {
      visible.value = true;
    }
    _animController.forward();
  }

  /// 隐藏控制栏（带动画，resize/模态窗口/钉住中不隐藏 — 对齐 media_kit 原生:
  /// 暂停状态同样可隐藏).
  void hide() {
    // 将 resize/modal/pinned gate 放在最终状态转换处：已进入事件队列的旧 Timer 回调
    // 即使无法再被 cancel，也不能在会话内启动淡出动画。
    if (_resizing || _modalOpen || _pinned) return;
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
  /// 对齐 media_kit 原生: 隐藏与播放状态无关 — 未 resize、无模态窗口、
  /// 无活跃子控件交互时计时隐藏。
  void scheduleHide() {
    _hideTimer?.cancel();
    if (_resizing || _modalOpen || _activeInteractionCount > 0 || _pinned) {
      return;
    }
    _hideTimer = Timer(_hideDelay, () {
      // v0.0.4:显现/保活的响应区已由 UI 层 MouseRegion 门控到控制栏本体矩形
      // (见 PlayerVideoControls.isPointerInsideControlBar) — 指针移出矩形
      // 即不再刷新计时,静止或悬停区外 3s 后照常隐藏。
      if (_activeInteractionCount == 0) hide();
    });
  }

  /// 空置态固定显示 (v0.0.6) — 无媒体时控制栏是唯一操作入口
  /// (打开文件/播放列表/设置/全屏), 不参与自动隐藏; 置回 false 恢复
  /// 既有静置计时策略.
  ///
  /// 特例声明: media_kit 原生交互无"空置态"概念 (空置页是项目自有的
  /// empty state), 本钉住语义不违背播放中的"状态无关隐藏"对齐原则.
  set pinned(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    if (value) {
      // 钉住: 立即唤起 + 取消在途隐藏计时.
      _hideTimer?.cancel();
      show();
    } else {
      // 解除: 回到常规静置计时.
      scheduleHide();
    }
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

  /// 打开中的模态窗口 (设置/菜单等) — 开窗冻结自动隐藏计时,
  /// 关窗后重新计时 (v0.0.5: 已显示的控制栏在模态开启期间保持显示).
  set modalOpen(bool value) {
    if (_modalOpen == value) return;
    _modalOpen = value;
    if (value) {
      _hideTimer?.cancel();
    } else {
      // 关闭后重新开始计时 — 不强制 show (若已隐藏保持隐藏).
      scheduleHide();
    }
  }

  /// 鼠标移动（节流 100ms）— 对齐 media_kit 原生: 暂停时 hover 同样唤起.
  void onMouseMove() {
    if (_resizing) return;
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottle) return;
    _lastHoverTime = now;
    show();
    scheduleHide();
  }

  /// 鼠标进入。
  ///
  /// Resize 期间仍记录实际 pointer 状态，但不改变 controls 可见性：窗口拖动时
  /// 不应因迟到的 enter 事件重新显示已自动隐藏的 controls。
  void onMouseEnter() {
    _hovering = true;
    if (_resizing) return;
    show();
    scheduleHide();
  }

  /// 鼠标离开 — 静置计时隐藏 (对齐 media_kit 原生, 状态无关).
  void onMouseExit() {
    _hovering = false;
    scheduleHide();
  }

  /// isPlaying 变化处理 — 由 [_isPlaying] listener 自动触发。
  ///
  /// 对齐 media_kit 原生: 状态切换瞬间唤起控件 (暂停/恢复同理), 之后
  /// 静置照常计时隐藏 — 无"非 playing 永显"特例。
  void _onPlayingChanged() {
    _activeInteractionCount = 0;
    show();
    scheduleHide();
  }

  /// 开始一个子控件交互会话，冻结自动隐藏。
  ///
  /// UI 子组件只报告交互边界，不自行维护隐藏 Timer，避免拖拽、悬停和 popup
  /// 的异步结束顺序造成控制栏提前消失。
  void onInteractionStart() {
    _activeInteractionCount++;
    show();
    _hideTimer?.cancel();
  }

  /// 结束一个子控件交互会话；最后一个会话结束后恢复既有隐藏策略。
  void onInteractionEnd() {
    if (_activeInteractionCount == 0) {
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

  /// 初始状态：显示控制栏并启动自动隐藏计时 (状态无关, 对齐 media_kit 原生).
  void init() {
    visible.value = true;
    _animController.value = 1;
    scheduleHide();
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
