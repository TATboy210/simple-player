import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// services: KeyDownEvent / LogicalKeyboardKey / KeyEventResult / FocusNode
// (material.dart 不完整导出 services 的键盘事件类型)
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/window_bridge/window_bridge.dart';
import '../shared/osd_overlay.dart';
import '../theme/tokens.dart';
import 'auto_hide_controller.dart';
import 'control_bar.dart';
import 'control_bar_view_model.dart';
import 'media_kit_player_port.dart';
import 'player_actions.dart';
import 'player_units.dart';

/// media_kit [Player] 的可测试端口 — 抽象出 [PlayerControlsState] 所需的
/// stream、快照与精细交互控制。
///
/// 控制栏展示状态直连 `player.stream`，避免引擎镜像状态带来的帧间延迟；基础
/// 播放命令则经 [PlayerActions] 统一进入项目播放控制门面。本端口只保留
/// 进度条 seek-hold 与倍速所需的直接 Player 操作。
abstract interface class PlayerPort {
  /// 播放状态流
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;

  /// 位置流(Duration)
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;

  /// 音量(0-100 media_kit 语义)/倍速流
  Stream<double> get volume;
  Stream<double> get rate;

  /// 初始快照(init 时读一次,避免首帧空白)
  bool get isPlayingNow;
  bool get isBufferingNow;
  Duration get positionNow;
  Duration get durationNow;
  double get volumeNow; // 0-100
  double get rateNow;

  /// 进度条与倍速的精细交互仍直达 player。
  void seek(Duration position);
  void setRate(double rate);
}

/// 当前 media_kit `Video.controls` 实例的可测试端口。
///
/// 生产实现始终包装当前 route 的 [VideoState]，确保全屏切换与字幕 padding 不会
/// 错发到窗口态的旧实例；测试实现可使用纯 Dart [PlayerPort]，避免加载 libmpv。
abstract interface class VideoControlsPort {
  /// 当前视频实例共享的播放器状态与精细交互端口。
  PlayerPort get player;

  /// 当前 controls 是否位于 media_kit fullscreen route。
  bool get isFullscreen;

  /// 包装的 VideoState 是否仍可安全接收字幕 padding 更新。
  bool get isMounted;

  /// 当前字幕配置的基础 padding。
  EdgeInsets get subtitlePadding;

  /// 使用当前 VideoState 切换 media_kit 原生全屏 route。
  void toggleFullscreen();

  /// 使用当前 VideoState 退出 media_kit 原生全屏 route。
  void exitFullscreen();

  /// 更新当前 VideoState 的字幕安全区。
  void setSubtitleViewPadding(EdgeInsets padding);
}

/// 将 media_kit [VideoState] 适配为 [VideoControlsPort]。
final class MediaKitVideoControlsPort implements VideoControlsPort {
  MediaKitVideoControlsPort(this._state)
    : player = MediaKitPlayerPort(_state.widget.controller.player);

  final VideoState _state;

  @override
  final PlayerPort player;

  @override
  bool get isFullscreen => _state.isFullscreen();

  @override
  bool get isMounted => _state.mounted;

  @override
  EdgeInsets get subtitlePadding =>
      _state.widget.subtitleViewConfiguration.padding;

  @override
  void toggleFullscreen() => _state.toggleFullscreen();

  @override
  void exitFullscreen() => _state.exitFullscreen();

  @override
  void setSubtitleViewPadding(EdgeInsets padding) =>
      _state.setSubtitleViewPadding(padding);
}

/// 路径B 控制栏的状态容器 — 订阅 [PlayerPort] stream 转写为 [ValueNotifier]。
///
/// 字段用 `ValueNotifier<int>` ms(非 Duration)对齐 ProgressBar seek-hold 的
/// int 差值比较,零改动迁移。volume 用 0-1(项目语义),从 media_kit 0-100 转换。
/// mute/volume 写走 [engine](保 `_preMuteVolume`),不写 [PlayerPort]。
class PlayerControlsState {
  PlayerControlsState(this._port, {required MediaEngine engine})
    : _engine = engine;

  PlayerPort _port;
  MediaEngine _engine;

  // ─── 播放状态 ───
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> buffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> completed = ValueNotifier<bool>(false);

  // ─── 位置(int ms — 对齐 seek-hold int 比较)───
  final ValueNotifier<int> positionMs = ValueNotifier<int>(0);
  final ValueNotifier<int> durationMs = ValueNotifier<int>(0);
  final ValueNotifier<int> bufferedMs = ValueNotifier<int>(0);

  // ─── 音量(0-1)/倍速 ───
  final ValueNotifier<double> volume01 = ValueNotifier<double>(1.0);
  final ValueNotifier<double> rate = ValueNotifier<double>(1.0);

  /// 静音状态 — 直接复用 engine.isMuted(避免双源)
  ValueListenable<bool> get isMuted => _engine.isMuted;

  // ─── stream 订阅 ───
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<double>? _rateSub;

  /// 订阅 [PlayerPort] stream + 初始快照。必须在 widget initState 调用。
  void init() {
    _cancelSubscriptions();
    // 初始快照 — 避免首帧空白(订阅前的旧值)
    isPlaying.value = _port.isPlayingNow;
    buffering.value = _port.isBufferingNow;
    positionMs.value = ms(_port.positionNow);
    durationMs.value = ms(_port.durationNow);
    volume01.value = volumeFromMediaKit(_port.volumeNow);
    rate.value = _port.rateNow;

    _playingSub = _port.playing.listen((v) => isPlaying.value = v);
    _bufferingSub = _port.buffering.listen((v) => buffering.value = v);
    _completedSub = _port.completed.listen((v) => completed.value = v);
    _positionSub = _port.position.listen((d) => positionMs.value = ms(d));
    _durationSub = _port.duration.listen((d) => durationMs.value = ms(d));
    _bufferSub = _port.buffer.listen((d) => bufferedMs.value = ms(d));
    _volumeSub = _port.volume.listen(
      (v) => volume01.value = volumeFromMediaKit(v),
    );
    _rateSub = _port.rate.listen((v) => rate.value = v);
  }

  /// 迁移到新的视频端口和引擎，同时复用现有 notifier 保持下游 identity。
  void updateSources(PlayerPort port, {required MediaEngine engine}) {
    _port = port;
    _engine = engine;
    init();
  }

  void _cancelSubscriptions() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _volumeSub?.cancel();
    _rateSub?.cancel();
    _playingSub = null;
    _bufferingSub = null;
    _completedSub = null;
    _positionSub = null;
    _durationSub = null;
    _bufferSub = null;
    _volumeSub = null;
    _rateSub = null;
  }

  /// seek(int ms)— 乐观更新 positionMs 再 player.seek.
  ///
  /// 关键:乐观更新让 ProgressBar seek-hold 立即到达容差触发 _finishSeekHold,
  /// 否则卡 2000ms 超时兜底(见计划"最大障碍")。
  void seek(int milliseconds) {
    final clamped = milliseconds.clamp(0, durationMs.value);
    positionMs.value = clamped;
    _port.seek(fromMs(clamped));
  }

  /// 倍速 — 直写 player
  void setRate(double r) => _port.setRate(r);

  /// 音量(0-1)— 写走 engine(保 _preMuteVolume 语义),不写 player
  void setVolume(double v01) => _engine.setVolume(v01);

  /// 静音切换 — 写走 engine,不写 player
  void toggleMute() => _engine.setMute(!_engine.isMuted.value);

  /// 取消订阅 + dispose 自建 notifiers(不 dispose engine.isMuted — engine 拥有)
  void dispose() {
    _cancelSubscriptions();
    isPlaying.dispose();
    buffering.dispose();
    completed.dispose();
    positionMs.dispose();
    durationMs.dispose();
    bufferedMs.dispose();
    volume01.dispose();
    rate.dispose();
  }
}

/// 路径B 顶层 builder — 由 [PlayerScreen._buildControls] 调用.
///
/// 第一个参数 [VideoState] 对应 media_kit `VideoControlsBuilder` 签名
/// (`Widget Function(VideoState)`);命名参数由 `_buildControls` 闭包捕获的稳定
/// 对象填充。内部构造 [PlayerVideoControls]。
///
/// 不直接赋给 `Video.controls` — 赋值的是 `_buildControls`(单参闭包),本函数
/// 是其内部的 helper,接受命名参数降低 _buildControls 复杂度。
Widget playerVideoControls(
  VideoState state, {
  required MediaEngine engine,
  required PlayerActions actions,
  required ValueListenable<String> currentFileName,
  required ValueListenable<WindowMode> windowMode,
  Widget? emptyState,
  ValueListenable<bool>? resizing,
}) {
  return PlayerVideoControls(
    video: MediaKitVideoControlsPort(state),
    engine: engine,
    actions: actions,
    currentFileName: currentFileName,
    windowMode: windowMode,
    emptyState: emptyState,
    resizing: resizing,
  );
}

/// 路径B 控制栏 widget — 数据源直连 media_kit [Player.stream]。
///
/// 控制层由 Stack 组合空状态、控制栏、错误提示和鼠标唤起区域:
/// - 播放/位置/时长/倍速/音量(读): [PlayerControlsState] 订阅 `player.stream`
/// - 播放/暂停、快退、快进(写): 经 [PlayerActions] 进入 PlaybackController 门面
/// - 进度条 seek/倍速(写): 经 [PlayerPort] 直写 `player`，保留低延迟精细交互
/// - 音量/静音(写): 走 [MediaEngine](保 `_preMuteVolume` 语义)
/// - isFullscreen: 由 [WindowMode] 单一数据源驱动(图标/auto-hide/cursor/
///   ESC)。不再读 route 本地 [VideoState.isFullscreen] — media_kit 在全屏
///   期间把窗口态 VideoState 的 context 换成 route context(窗口态实例读
///   true),退出后 refreshView 为空实现且参数相等抑制重建,notifier 永不
///   同步回 false(按钮图标卡死根因)。
///
/// 阶段2 适配 route 约束(修实机 3 bug):
/// - **AutoHide 改 isPlaying**:[PlayerControlsState.isPlaying] 驱动,非 playing 永显
/// - **删 visibleSink 跨层**:字幕 padding 由本控件监听 [_autoHide.visible] 调
///   `widget.video.setSubtitleViewPadding`(每实例调自己 VideoState,修"自动隐藏
///   失效"根因 — 旧路径 PlayerScreen 用窗口态 _videoKey,全屏 route 调错对象)
/// - **键盘住进 controls**:[Focus] + autofocus + onKeyEvent 最小集(ESC/F/Space/
///   方向键),全屏 route 复制 builder 时自动携带(修"退出 deactivated" — 旧路径
///   KeyboardHandler 在 builder 外不进 route)
/// - **MouseRegion cursor**:全屏 + 控件隐藏 → none(沉浸),替代旧 PlayerScreen
///   _controlsVisible 跨层驱动
class PlayerVideoControls extends StatefulWidget {
  /// 当前 route 的视频控制端口；生产环境由 [MediaKitVideoControlsPort] 包装
  /// media_kit [VideoState]，测试可注入不加载原生库的 fake。
  final VideoControlsPort video;

  final MediaEngine engine;
  final PlayerActions actions;

  /// 活动文件名 — 驱动 ControlBar 标题 + 空状态判定(hasMedia 依赖它)。
  final ValueListenable<String> currentFileName;

  /// 空状态页 — 空状态(idle && !hasMedia)时在 Stack 最底层渲染。
  final Widget? emptyState;

  /// 窗口模式单一数据源 — 驱动全屏按钮图标、auto-hide 延迟、cursor 与 ESC。
  ///
  /// 窗口态与全屏 route 的 controls 实例监听同一 mode,进出全屏时 setMode
  /// 必然提交状态,图标/标题栏/cursor 同步还原,不依赖 Video 重建时序。
  final ValueListenable<WindowMode> windowMode;

  /// 窗口 resize 信号 — 传递给 ControlBar 跳过 BackdropFilter。
  final ValueListenable<bool>? resizing;

  /// 仅供 widget 测试观测外层 build 次数，不参与生产渲染逻辑。
  @visibleForTesting
  final VoidCallback? onBuild;

  const PlayerVideoControls({
    super.key,
    required this.video,
    required this.engine,
    required this.actions,
    required this.currentFileName,
    required this.windowMode,
    this.emptyState,
    this.resizing,
    this.onBuild,
  });

  @override
  State<PlayerVideoControls> createState() => _PlayerVideoControlsState();
}

class _PlayerVideoControlsState extends State<PlayerVideoControls>
    with TickerProviderStateMixin {
  /// 路径B 核心:从当前 route 的视频端口订阅 Player stream。全屏 route 复用
  /// 同一个 Player，但每个 controls 实例独立维护展示状态与生命周期。
  late final PlayerControlsState _controlsState = PlayerControlsState(
    widget.video.player,
    engine: widget.engine,
  );

  /// TickerProviderStateMixin: AutoHideController + _animController 各需一个 ticker
  late final AutoHideController _autoHide;
  final _popupCloseNotifier = ValueNotifier<int>(0);
  Timer? _clickTimer;

  /// 阶段2:键盘 Focus — controls 自带 FocusNode + autofocus,全屏 route 复制
  /// builder 时自动携带。项目 `Video` 未传 focusNode(player_screen.dart:429-433),
  /// 全屏 route focusNode=null → 不自带 Focus 键盘事件收不到(见计划风险处理2)。
  late final FocusNode _focusNode = FocusNode();

  /// 派生 isFullscreen — 由 widget.windowMode 驱动(单一数据源),供全屏按钮
  /// 图标动态切换。mode 监听在 _attachLifecycleListeners 挂载。
  late final ValueNotifier<bool> _isFullscreenNotifier;

  /// 共享 AnimationController — 驱动 resize 淡出/淡入和 decoration 状态切换
  /// 150ms,初始 value=1.0(不 resize 时完全可见)
  late final AnimationController _animController;

  /// resize 状态标记 — resize 期间忽略 engine 状态变化,避免 controller 竞争
  bool _isResizing = false;

  /// 空状态使用的媒体身份监听器；控制栏只接收其中的局部监听器。
  late Listenable _mediaIdentityListenable;

  /// 将 idle 状态变化限制在中央控制组，同时保留装饰动画独立监听。
  late final ValueNotifier<bool> _isIdleNotifier;

  /// 全屏切换过渡标记 — 跳过 isResizing 触发的控制栏淡出,避免全屏切换闪烁消失。
  /// mode 进出全屏时置位,resize 平息后由 _onResizeChanged 清除。
  bool _isFullscreenTransition = false;

  /// 阶段3 bug1:deactivate 标记 — 挡 LayoutBuilder 在 inactive element 上触发
  /// 的 didUpdateWidget/build 查 isFullscreen(查 ancestor 会断言)。
  /// deactivate() 即置 true(element 仍 mounted 但 inactive,State.mounted 无效)。
  bool _isDeactivating = false;
  bool _lifecycleListenersAttached = false;
  bool _subtitleSyncScheduled = false;

  /// 控件创建后读取一次的字幕基础 padding，避免 activate 重复叠加自身 inset。
  EdgeInsets? _subtitleBasePadding;

  /// 控制栏可见时为字幕预留的底部安全区。
  static const _subtitleControlBarInset = EdgeInsets.only(
    bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
  );

  /// 复用控制栏的只读数据绑定，避免 auto-hide/父层 build 时重复创建。
  ///
  /// 该对象只持有 [_controlsState] 的 notifier 和稳定回调；播放器 source
  /// 切换时 notifier identity 会被保留，因此无需随每次 stream 更新重建。
  late ControlBarViewModel _controlBarViewModel;

  /// 对齐 media_kit 原生 onTapUp 400ms 双击窗口。
  static const _clickDelayMs = 400;

  /// 切换全屏 — 双击与全屏按钮共用入口。
  ///
  /// media_kit 执行真实 route 切换，宿主只接收结果同步窗口语义。
  /// (push/pop PageRouteBuilder)。用**本实例** [widget.video] — 窗口态
  /// isFullscreen()=false→enter, 全屏态 =true→exit, 自动正确分支
  /// (修复症状④退出渲染出错,见 memory [[project_fullscreen_minimal_fix]])。
  void _toggleFullscreen() {
    if (!mounted || _isDeactivating || !widget.video.isMounted) return;
    // media_kit 负责真实 route 切换，宿主只在根 Video 生命周期回调中同步状态。
    widget.actions.onToggleFullscreen?.call();
    // The host callback may synchronously pop the fullscreen route, so re-check
    // lifecycle before touching the route-local VideoState.
    if (!mounted || _isDeactivating || !widget.video.isMounted) return;
    widget.video.toggleFullscreen();
  }

  /// 阶段2:字幕 padding 自驱 — 监听 [_autoHide.visible] 调本实例 VideoState.
  ///
  /// 修"自动隐藏失效"根因:旧路径 PlayerScreen._onControlsVisibleChanged 用窗口态
  /// `_videoKey.currentState` 调 setSubtitleViewPadding,全屏 route 时全屏 VideoState
  /// 是另一实例,padding 调错对象 → 字幕被控制栏遮挡/控件隐藏字幕不动。本控件每实例
  /// 监听自己 _autoHide.visible,调 `widget.video`(本实例)→ 双实例各自正确。
  void _scheduleSubtitlePaddingSync() {
    if (_subtitleSyncScheduled || _isDeactivating || !mounted) return;
    // 空闲阶段没有正在进行的 widget build，可立即同步，保持 stream 事件的
    // 即时性；build/update 通知期间则延迟到 frame 结束，避免触发 SubtitleView
    // 的内部 setState() during build。
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _syncSubtitlePadding();
      return;
    }
    _subtitleSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subtitleSyncScheduled = false;
      _syncSubtitlePadding();
    });
  }

  void _syncSubtitlePadding() {
    // 阶段3:退出全屏 route pop(Duration.zero) 后,全屏 VideoState deactivate/dispose。
    // post-frame callback(line 413) 或 _autoHide.visible listener 可能在本控件
    // 失效后触发本方法,调用已 deactivate 的 widget.video.setSubtitleViewPadding
    // 会更新 media_kit _videoViewParametersNotifier → 触发全屏 Video rebuild →
    // 查已 deactivate 的 InheritedWidget ancestor → "deactivated widget's
    // ancestor" 断言(framework.dart:6417)。mounted 挡本控件 dispose 后;
    // widget.video.isMounted 挡全屏 VideoState dispose 后。
    // _isDeactivating 覆盖 State 仍 mounted 但 Element 已 inactive 的窗口，
    // 也能拦截不可取消的 post-frame callback。
    if (_isDeactivating || !mounted || !widget.video.isMounted) return;
    final videoState = widget.video;
    // 只在当前 source 首次同步时读取基础值；之后始终复用缓存，保证重复
    // activate/reparent 不会把本控件已经添加的 inset 再次当作基础值。
    final base = _subtitleBasePadding ??= videoState.subtitlePadding;
    final padding = _autoHide.visible.value
        ? base + _subtitleControlBarInset
        : base;
    videoState.setSubtitleViewPadding(padding);
  }

  /// 阶段2:键盘事件处理 — controls 内 Focus 最小集.
  ///
  /// 全屏 route 复制 builder 时自动携带(KeyboardHandler 在 builder 外不进 route)。
  /// 最小集:ESC(退出全屏)/F(切换全屏)/Space(播放暂停)/←→(seek ±5s)。
  /// 其余键(N/P/O/S/M/[]/F1/媒体键)return ignored 冒泡给窗口态 KeyboardHandler
  /// (全屏 route 缺这些键 — 已知限制,计划 line 85 认可)。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isDeactivating || !mounted || !widget.video.isMounted) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      // ESC:仅全屏态退出(窗口态 ESC 冒泡给 KeyboardHandler 关播放列表/设置)。
      // 全屏判定用 mode 单一数据源 — 窗口态实例在全屏期间同样收到该键时
      // (焦点回落边界)也能正确退出,不再依赖 route 本地 context 查询。
      if (widget.windowMode.value.isFullscreen) {
        widget.actions.onToggleFullscreen?.call();
        // Route callbacks may deactivate this VideoState synchronously.
        if (!mounted || _isDeactivating || !widget.video.isMounted) {
          return KeyEventResult.handled;
        }
        widget.video.exitFullscreen();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      widget.actions.onPlayPause?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.actions.onSeekBack?.call(Tokens.skipShortMs);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.actions.onSeekForward?.call(Tokens.skipLongMs);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _mediaIdentityListenable = Listenable.merge([
      widget.engine.state,
      widget.currentFileName,
    ]);
    _isIdleNotifier = ValueNotifier<bool>(
      widget.engine.state.value == MediaState.idle,
    );
    // 单一数据源:初始值与后续变化都来自 windowMode,不读 route 本地
    // VideoState.isFullscreen(会被 media_kit context 交换污染)。
    _isFullscreenNotifier = ValueNotifier<bool>(
      widget.windowMode.value.isFullscreen,
    );
    // 阶段2:_controlsState.init() 前置 — isPlaying 有真值后再构造 _autoHide
    // (AutoHide 监听 _controlsState.isPlaying,init() 读初值)。
    _controlsState.init(); // 订阅 player.stream + 初始快照
    _controlBarViewModel = _createControlBarViewModel();
    _autoHide = AutoHideController(
      vsync: this,
      // 阶段2:AutoHide 用 _controlsState.isPlaying(player.stream 驱动)。
      isPlaying: _controlsState.isPlaying,
      // 隐藏延迟由 mode 决定(全屏 3s/窗口态 5s),与图标同源。
      isFullscreen: _isFullscreenNotifier.value,
      popupCloseNotifier: _popupCloseNotifier,
    );
    _autoHide.init();

    // 创建共享 AnimationController — 初始 value=1.0(不 resize 时完全可见)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationNormal),
      value: 1.0,
    );

    // 监听 resize 信号变化
    _attachLifecycleListeners();
    // CB-06: 防御性同步 — widget 创建时 resizing 可能已为 true
    if (widget.resizing?.value == true) _onResizeChanged();

    // 阶段2:字幕 padding 自驱(每实例调自己 VideoState)。post-frame 确保
    // widget.video 已挂载(setSubtitleViewPadding 需 VideoState 已构建)。
    _scheduleSubtitlePaddingSync();
  }

  /// 由 [WindowMode] 同步全屏派生状态(图标/auto-hide/过渡标记)。
  ///
  /// 替代旧的 route 本地 VideoState.isFullscreen 现取:mode 由每条进出全屏
  /// 路径的 setMode 提交,窗口态实例在全屏期间不会被 context 交换污染,
  /// 退出后必然同步回 false(修按钮图标卡死)。
  void _syncModeFullscreen() {
    final fs = widget.windowMode.value.isFullscreen;
    if (_isFullscreenNotifier.value != fs) {
      _isFullscreenNotifier.value = fs;
      _autoHide.isFullscreen = fs;
      // 标记过渡,下次 isResizing=true 跳过 reverse() — 抑制切换期控制栏
      // 闪烁,同时避免窗口恢复 resize 期间动画竞争(退出单帧异常的候选源)。
      _isFullscreenTransition = true;
    }
  }

  void _handleTap() {
    if (_clickTimer?.isActive ?? false) {
      // 第二次点击在延迟内 → 双击,切换全屏
      _clickTimer?.cancel();
      _toggleFullscreen();
    } else {
      // D-04: 第一次点击 → 立即隐藏(不等延迟)
      if (widget.engine.state.value != MediaState.idle) {
        _autoHide.hide();
      }
      // Timer 仅用于双击检测窗口(超时自动失效,空回调)
      _clickTimer = Timer(const Duration(milliseconds: _clickDelayMs), () {});
    }
  }

  /// resize 信号变化回调 — resizing=true 时 reverse() 淡出,false 时根据 engine 状态恢复。
  /// 全屏切换期间(_isFullscreenTransition=true)跳过 reverse(),避免控制栏闪烁消失。
  void _onResizeChanged() {
    final resizing = widget.resizing?.value ?? false;
    // CB-06: 同步 AutoHideController — resize 期间冻结隐藏计时器
    _autoHide.resizing = resizing;
    if (resizing) {
      _isResizing = true;
      if (!_isFullscreenTransition) {
        _animController.reverse(); // 1.0 → 0.0,150ms easeOut
      }
    } else {
      _isResizing = false;
      _isFullscreenTransition = false; // 清除标记,恢复正常 resize 行为
      final isIdle = widget.engine.state.value == MediaState.idle;
      // resize 期间状态变化被暂缓，结束时补同步中央按钮视觉状态。
      _isIdleNotifier.value = isIdle;
      if (isIdle) {
        _animController.reverse(); // 恢复到 idle 装饰
      } else {
        _animController.forward(); // 恢复到 playing 装饰
      }
    }
  }

  void _attachLifecycleListeners() {
    if (_lifecycleListenersAttached) return;
    widget.engine.state.addListener(_onEngineStateChanged);
    widget.windowMode.addListener(_syncModeFullscreen);
    widget.resizing?.addListener(_onResizeChanged);
    _autoHide.visible.addListener(_scheduleSubtitlePaddingSync);
    _lifecycleListenersAttached = true;
  }

  void _detachLifecycleListeners() {
    if (!_lifecycleListenersAttached) return;
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.windowMode.removeListener(_syncModeFullscreen);
    widget.resizing?.removeListener(_onResizeChanged);
    _autoHide.visible.removeListener(_scheduleSubtitlePaddingSync);
    _lifecycleListenersAttached = false;
  }

  void _onEngineStateChanged() {
    // resize 期间忽略 engine 状态变化,避免 controller 竞争(Pitfall 2)
    if (_isResizing) return;
    // 阶段2:AutoHide 自动监听 _controlsState.isPlaying(player.stream 驱动),
    // 不需手动调 _autoHide.onEngineStateChanged()。本回调仅驱动 decoration 切换。

    // engine 状态变化驱动 decoration 切换:idle→reverse(淡出),playing→forward(淡入)
    final isIdle = widget.engine.state.value == MediaState.idle;
    _isIdleNotifier.value = isIdle;
    if (isIdle) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 阶段3 bug1 历史教训(保留 _isDeactivating 守卫):route pop 期间
    // element 处于 inactive(deactivate 已调、dispose 未调),此时
    // mounted 仍 true 但 ancestor 查询会断言 — deactivate 置位、
    // didUpdateWidget/build 检查 flag 跳过 port 状态读取。本控件不 reparent,
    // 无需 activate 重置。
    //
    // 全屏状态改由 windowMode 单一数据源驱动(C2):不再在此读
    // route 本地 VideoState.isFullscreen — media_kit 全屏期间把窗口态
    // VideoState 的 context 换成 route context(窗口态实例读 true),退出
    // 后 refreshView 为空实现且 VideoViewParameters 相等抑制重建,旧路径
    // 图标永不同步回(false 卡死根因,见类注释)。mode 由每条进出全屏路径
    // 的 setMode 提交,经 _syncModeFullscreen(亦由 windowMode 监听直驱)
    // 同步图标 + AutoHide + 过渡标记。
    if (!_isDeactivating) {
      _syncModeFullscreen();
    }
    // 视频端口或引擎更换时迁移控制状态，避免新外壳继续驱动旧数据源。
    final sourceChanged =
        oldWidget.video != widget.video || oldWidget.engine != widget.engine;
    if (sourceChanged) {
      _controlsState.updateSources(widget.video.player, engine: widget.engine);
      // 只有 VideoState 更换时基础 padding 才失效；仅替换 engine 时，
      // 复用同一视频端口可避免把已加过的 control bar inset 再次当作基础值。
      if (oldWidget.video != widget.video) _subtitleBasePadding = null;
      // active replacement 不一定伴随可见性、resize 或 engine 状态变化，
      // 因此必须立即把当前控制栏可见性同步到新的 VideoState；inactive 阶段
      // 则延迟到 activate，避免访问已经脱离祖先树的 media_kit 状态。
      if (!_isDeactivating) _scheduleSubtitlePaddingSync();
    }
    // engine 更换时迁移状态监听，并同步局部 idle 信号，避免沿用旧引擎状态。
    if (oldWidget.engine.state != widget.engine.state) {
      oldWidget.engine.state.removeListener(_onEngineStateChanged);
      if (_lifecycleListenersAttached) {
        widget.engine.state.addListener(_onEngineStateChanged);
      }
      _isIdleNotifier.value = widget.engine.state.value == MediaState.idle;
    }
    // 媒体身份源变化时更新缓存的合并监听器；避免 build 中反复创建新实例。
    if (oldWidget.engine.state != widget.engine.state ||
        oldWidget.currentFileName != widget.currentFileName) {
      _mediaIdentityListenable = Listenable.merge([
        widget.engine.state,
        widget.currentFileName,
      ]);
    }
    // windowMode 监听迁移 — 窗口服务替换时须解除旧 notifier,否则旧服务的
    // mode 状态继续驱动本控件;active 阶段立即按新源同步一次。
    if (oldWidget.windowMode != widget.windowMode) {
      oldWidget.windowMode.removeListener(_syncModeFullscreen);
      if (_lifecycleListenersAttached) {
        widget.windowMode.addListener(_syncModeFullscreen);
      }
      if (!_isDeactivating) _syncModeFullscreen();
    }
    // resizing 监听迁移 — inactive 期间只更新 source，activate 再统一连接。
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_onResizeChanged);
      if (_lifecycleListenersAttached) {
        widget.resizing?.addListener(_onResizeChanged);
        _onResizeChanged();
      }
    }
    // actions 变化时仅刷新包含回调闭包的 ViewModel；播放状态 notifier 仍复用，
    // 避免把一次宿主回调替换扩散成整套控制状态订阅重建。
    if (oldWidget.actions != widget.actions) {
      _controlBarViewModel = _createControlBarViewModel();
    }
  }

  @override
  void deactivate() {
    _isDeactivating =
        true; // 阶段3 bug1:标记 inactive,挡后续 didUpdateWidget/build 查 ancestor
    // 阶段3:deactivate 即断开外部 listener — 退出全屏 route pop(Duration.zero)
    // 后全屏 VideoState 即将 deactivate,但 _autoHide 的 _hideTimer/_animController
    // 在 deactivate→dispose 之间仍可能触发 visible 变化(playing 态 Timer / stream
    // isPlaying 推送 / resize 信号),经 _autoHide.visible listener 触发
    // _syncSubtitlePadding 调已 deactivate 的 widget.video.setSubtitleViewPadding
    // → media_kit 查 deactivated ancestor 断言。dispose 太晚(Timer/动画仍跑),
    // 须在此断开。dispose 内 removeListener 幂等保留(remove 已移除的 listener 是
    // no-op)。reparent 场景由 activate() 统一恢复，避免 inactive 期间重复注册。
    _detachLifecycleListeners();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isDeactivating = false;
    _attachLifecycleListeners();
    _onResizeChanged();
    _isIdleNotifier.value = widget.engine.state.value == MediaState.idle;
    _scheduleSubtitlePaddingSync();
  }

  @override
  void dispose() {
    _detachLifecycleListeners();
    _clickTimer?.cancel();
    _focusNode.dispose();
    _popupCloseNotifier.dispose();
    _isFullscreenNotifier.dispose();
    _animController.dispose();
    _isIdleNotifier.dispose();
    _autoHide.dispose();
    _controlsState.dispose(); // 取消 stream 订阅 + dispose notifiers
    super.dispose();
  }

  /// 空状态页 — 仅 idle && !hasMedia 时渲染,直接可交互（打开入口常驻）。
  Widget _buildEmptyState(bool active) {
    if (!active) return const SizedBox.shrink();
    // emptyState 契约非空, `?? SizedBox.shrink()` 防御性兜底消除 `!`
    return widget.emptyState ?? const SizedBox.shrink();
  }

  /// 根据播放状态构建空状态页和上方手势区。
  ///
  /// 只监听空状态判定所需的两个 notifier，避免文件名或 idle 状态变化时
  /// 重新执行 OSD、错误横幅和鼠标区域的构建逻辑。
  Widget _buildEmptyAndGesture() {
    return ListenableBuilder(
      listenable: _mediaIdentityListenable,
      builder: (context, _) {
        final isIdle = widget.engine.state.value == MediaState.idle;
        final emptyActive =
            widget.emptyState != null && isIdle && !widget.engine.hasMedia;
        return Stack(
          children: [
            if (widget.emptyState != null)
              Positioned.fill(child: _buildEmptyState(emptyActive)),
            Positioned.fill(
              bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: emptyActive ? null : _handleTap,
                child: IgnorePointer(
                  ignoring: emptyActive,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建控制栏及其展示数据。
  /// 创建控制栏的只读数据绑定；调用方只在 source/actions 改变时调用。
  ControlBarViewModel _createControlBarViewModel() => ControlBarViewModel(
    isPlaying: _controlsState.isPlaying,
    position: _controlsState.positionMs,
    duration: _controlsState.durationMs,
    volume: _controlsState.volume01,
    isMuted: _controlsState.isMuted,
    rate: _controlsState.rate,
    isFullscreen: _isFullscreenNotifier,
    onSeek: _controlsState.seek,
    onPlayPause: widget.actions.onPlayPause ?? () {},
    onSeekBack: widget.actions.onSeekBack ?? (_) {},
    onSeekForward: widget.actions.onSeekForward ?? (_) {},
    onToggleMute: _controlsState.toggleMute,
    onSetVolume: _controlsState.setVolume,
    onSetRate: _controlsState.setRate,
  );

  ///
  /// 文件名和 idle 状态只在控制栏需要时监听；控制栏之外的稳定 overlay
  /// 不会因标题或空状态变化而重新 build。
  Widget _buildControlBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _autoHide.visible,
      builder: (_, isVisible, _) => Positioned(
        left: Tokens.controlBarMarginH,
        right: Tokens.controlBarMarginH,
        bottom: Tokens.controlBarMarginBottom,
        child: Visibility(
          key: const Key('player-controls-visibility'),
          visible: isVisible,
          maintainState: true,
          maintainAnimation: true,
          child: FadeTransition(
            opacity: _autoHide.opacity,
            child: ControlBar(
              vm: _controlBarViewModel,
              actions: widget.actions,
              isIdle: _isIdleNotifier.value,
              isIdleListenable: _isIdleNotifier,
              titleListenable: widget.currentFileName,
              // 透明尾段停用 backdrop readback，但保留完整交互祖先链。
              opacity: _autoHide.opacity,
              enableBlur: true,
              decoration: _animController,
              resizing: widget.resizing,
              onToggleFullscreen: _toggleFullscreen,
              onSeekStart: _autoHide.onSeekStart,
              onSeekEnd: _autoHide.onSeekEnd,
              onInteractionStart: _autoHide.onInteractionStart,
              onInteractionEnd: _autoHide.onInteractionEnd,
            ),
          ),
        ),
      ),
    );
  }

  /// 返回当前可安全读取的 fullscreen 状态(cursor 判定用)。
  ///
  /// mode 是 ValueNotifier 读取,无 ancestor 查询,但 deactivate 窗口内仍先
  /// 用生命周期标记短路,与 didUpdateWidget 的守卫语义保持一致。
  bool _isFullscreenForCursor() {
    if (_isDeactivating) return false;
    return widget.windowMode.value.isFullscreen;
  }

  @override
  Widget build(BuildContext context) {
    // 仅测试观测外层 build；状态监听仍下沉到真正依赖它的局部区域。
    widget.onBuild?.call();
    final isFullscreenForCursor = _isFullscreenForCursor();
    final controls = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // 空状态与手势共享判定，但不会触发其余 overlay 重建。
          Positioned.fill(child: _buildEmptyAndGesture()),
          RepaintBoundary(
            child: Stack(
              children: [
                // OSD 不依赖 engine.state/currentFileName，保持稳定 Element。
                Positioned(
                  bottom:
                      Tokens.controlBarMarginBottom +
                      Tokens.controlBarHeight +
                      12,
                  left: Tokens.controlBarMarginH,
                  right: Tokens.controlBarMarginH,
                  child: OsdOverlay(resizing: widget.resizing),
                ),
                _buildControlBar(),
                // 错误展示统一走 ErrorCardHost（app.dart builder 全局挂载，
                // 经 PlayerErrorReportBridge → ErrorReporter 呈现，D-07）。
              ],
            ),
          ),
          // 顶层 MouseRegion 仅监听 auto-hide 可见性，保持鼠标交互与 cursor 语义。
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _autoHide.visible,
              builder: (_, isVisible, _) => MouseRegion(
                opaque: false,
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: isFullscreenForCursor && !isVisible
                    ? SystemMouseCursors.none
                    : MouseCursor.defer,
                onHover: (event) {
                  final size = context.size;
                  if (size == null) return;
                  final mouseFromBottom = size.height - event.localPosition.dy;
                  if (mouseFromBottom < Tokens.bottomTriggerZoneHeight) {
                    _autoHide.onMouseMove();
                  }
                },
                onEnter: (_) => _autoHide.onMouseEnter(),
                onExit: (_) => _autoHide.onMouseExit(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
    // resize 期间控制栏 visible 子树随 MediaQuery 每帧 rebuild 重新发射
    // semantics → accessibility_bridge AXTree 每帧同步失败（"Nodes left pending
    // by the update: 34"）+ 错误日志洪流 + 语义遍历成本，白烧主线程 build 预算。
    // ExcludeSemantics(excluding: resizing) 在 resize 期间丢弃控制栏子树 semantics：
    // 控件本就视觉淡出（_animController.reverse）且用户在拖窗不读控件，suppress
    // 语义零可用性损失；settle 后 VLB 自动恢复 excluding=false，语义即恢复。
    // 用 ValueListenableBuilder 而非 .value 直读：parent build 不被 resizing
    // notifier 触发（build-boundary 契约），须 VLB 自身监听 settle 翻回。
    // null resizing（测试注入无 resize 源）走不包裹分支，保留既有语义断言。
    final resizing = widget.resizing;
    if (resizing == null) return controls;
    return ValueListenableBuilder<bool>(
      valueListenable: resizing,
      builder: (_, isResizing, _) => ExcludeSemantics(
        excluding: isResizing,
        child: controls,
      ),
    );
  }
}
