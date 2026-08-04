import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// hide Playlist: media_kit 也导出 Playlist 类,与项目 kernel/playlist/playlist.dart
// 的 Playlist 同名冲突。hide 掉 media_kit 的 Playlist,保留 Player(路径B 数据源)。
import 'package:media_kit/media_kit.dart' hide Playlist;
import 'package:media_kit_video/media_kit_video.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/playlist/playlist.dart';
import '../shared/osd_overlay.dart';
import '../theme/tokens.dart';
import 'auto_hide_controller.dart';
import 'control_bar.dart';
import 'control_bar_view_model.dart';
import 'error_banner.dart';
import 'media_kit_player_port.dart';
import 'player_actions.dart';
import 'player_units.dart';

/// media_kit [Player] 的可测试端口 — 抽象出 [PlayerControlsState] 所需的
/// stream + 快照 + 纯播放控制。
///
/// 路径B:控制栏直连 `player.stream`,但 [Player] 是 media_kit 具体类,headless
/// 测试环境无法构造(FFI mdk.dll 加载失败,见 memory
/// [[reference_mdk_dll_headless_test_failures]])。本接口用 Dart 标准类型暴露
/// 所需能力,生产用 `MediaKitPlayerPort` 包装真实 [Player],测试用 Fake。
///
/// 纯播放控制(playOrPause/seek/setRate)直写 player(路径B核心);volume/mute
/// 写走 [MediaEngine](保 `_preMuteVolume` 语义),不在此接口。
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

  /// 纯播放控制 — 直写 player(路径B)
  void playOrPause();
  void seek(Duration position);
  void setRate(double rate);
}

/// 路径B 控制栏的状态容器 — 订阅 [PlayerPort] stream 转写为 [ValueNotifier]。
///
/// 字段用 `ValueNotifier<int>` ms(非 Duration)对齐 ProgressBar seek-hold 的
/// int 差值比较,零改动迁移。volume 用 0-1(项目语义),从 media_kit 0-100 转换。
/// mute/volume 写走 [engine](保 `_preMuteVolume`),不写 [PlayerPort]。
class PlayerControlsState {
  PlayerControlsState(this._port, {required MediaEngine engine})
    : _engine = engine;

  final PlayerPort _port;
  final MediaEngine _engine;

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

  /// 播放/暂停 — 直写 player(路径B,跳过 engine 中间层)
  void playOrPause() => _port.playOrPause();

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
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _volumeSub?.cancel();
    _rateSub?.cancel();
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
  required Playlist playlist,
  required ValueListenable<int> playlistGeneration,
  required ValueListenable<String> currentFileName,
  required ValueListenable<bool> openFileEnabled,
  Widget? emptyState,
  ValueListenable<bool>? resizing,
  ValueNotifier<bool>? visibleSink,
}) {
  return PlayerVideoControls(
    state: state,
    engine: engine,
    actions: actions,
    playlist: playlist,
    playlistGeneration: playlistGeneration,
    currentFileName: currentFileName,
    openFileEnabled: openFileEnabled,
    emptyState: emptyState,
    resizing: resizing,
    visibleSink: visibleSink,
  );
}

/// 路径B 控制栏 widget — 数据源直连 media_kit [Player.stream]。
///
/// 与 [ControlsOverlay] 同构 Stack(空状态→RepaintBoundary[OsdOverlay+ControlBar
/// +ErrorBanner]→MouseRegion 唤起),差异仅在数据源/控制出口:
/// - 播放/位置/时长/倍速/音量(读): [PlayerControlsState] 订阅 `player.stream`
/// - 播放/seek/倍速(写): 直写 `player`(经 [PlayerPort]),跳过 [MediaEngine]
/// - 音量/静音(写): 走 [MediaEngine](保 `_preMuteVolume` 语义)
/// - skipBack/skipForward: 走 engine(项目语义糖,内部 seekTo→player.seek 一致)
/// - isFullscreen: 从 [VideoState.isFullscreen] 现取(每实例独立,修复"图标不动态")
///
/// 阶段1 暂保留 [ControlsOverlay](其测试 + 跨层 visibleSink)。阶段2 删旧 +
/// AutoHide 改 isPlaying + 键盘住进 controls + 删 visibleSink 跨层。
class PlayerVideoControls extends StatefulWidget {
  /// 本实例 media_kit [VideoState] — 数据源(`.widget.controller.player`)
  /// + 全屏 route 切换(`toggleFullscreen`)双用途。
  final VideoState state;

  final MediaEngine engine;
  final PlayerActions actions;

  /// 活动文件名 — 驱动 ControlBar 标题 + 空状态判定(hasMedia 依赖它)。
  final ValueListenable<String> currentFileName;

  /// 播放列表 — playMode 下沉到 LeftButtonGroup 内部读 mode。
  final Playlist playlist;

  /// 播放模式间接驱动源 — 切换 mode 时 generation++ 触发 LeftButtonGroup 重建。
  final ValueListenable<int> playlistGeneration;

  /// 空状态页 — 空状态(idle && !hasMedia)时在 Stack 最底层渲染。
  final Widget? emptyState;

  /// 打开文件入口可用性 — 空置页刚出现时隔离打开入口,等待旧媒体纹理退场。
  final ValueListenable<bool> openFileEnabled;

  /// 窗口 resize 信号 — 传递给 ControlBar 跳过 BackdropFilter。
  final ValueListenable<bool>? resizing;

  /// 控件可见性同步 sink — 阶段2 删除(改为 controls 内 AutoHide.visible 自驱)。
  final ValueNotifier<bool>? visibleSink;

  const PlayerVideoControls({
    super.key,
    required this.state,
    required this.engine,
    required this.actions,
    required this.currentFileName,
    required this.playlist,
    required this.playlistGeneration,
    required this.openFileEnabled,
    this.emptyState,
    this.resizing,
    this.visibleSink,
  });

  @override
  State<PlayerVideoControls> createState() => _PlayerVideoControlsState();
}

class _PlayerVideoControlsState extends State<PlayerVideoControls>
    with TickerProviderStateMixin {
  /// 路径B 核心:从本实例 VideoState 取 Player,经 [MediaKitPlayerPort] 订阅 stream。
  /// 全屏 route 复用同 Player,stream 推送至该实例 [PlayerControlsState](每实例独立,
  /// 修复"图标不动态"——旧路径 engine 是单例,全屏 route 的控制栏图标不随 player 状态变)。
  late final Player _player = widget.state.widget.controller.player;
  late final MediaKitPlayerPort _port = MediaKitPlayerPort(_player);
  late final PlayerControlsState _controlsState = PlayerControlsState(
    _port,
    engine: widget.engine,
  );

  /// TickerProviderStateMixin: AutoHideController + _animController 各需一个 ticker
  late final AutoHideController _autoHide;
  final _popupCloseNotifier = ValueNotifier<int>(0);
  Timer? _clickTimer;

  /// 派生 isFullscreen — 同步 widget.state.isFullscreen(),供全屏按钮图标动态切换。
  late final ValueNotifier<bool> _isFullscreenNotifier;

  /// 共享 AnimationController — 驱动 resize 淡出/淡入和 decoration 状态切换
  /// 150ms,初始 value=1.0(不 resize 时完全可见)
  late final AnimationController _animController;

  /// CurvedAnimation — easeOut 曲线,resize 期间 opacity 渐变(D-05/D-07)
  late final Animation<double> _resizeOpacity;

  /// resize 状态标记 — resize 期间忽略 engine 状态变化,避免 controller 竞争
  bool _isResizing = false;

  /// 全屏切换过渡标记 — 跳过 isResizing 触发的控制栏淡出,避免全屏切换闪烁消失。
  bool _isFullscreenTransition = false;

  /// 对齐 media_kit 原生 onTapUp 400ms 双击窗口(同 [ControlsOverlay._clickDelayMs])。
  /// 本类自带副本 — _clickDelayMs 在 ControlsOverlay 是 private,跨文件不可访问;
  /// 阶段2 删 ControlsOverlay 后此常量成为唯一来源。
  static const _clickDelayMs = 400;

  /// 同步 _autoHide.visible 到外部 sink — 单向(_autoHide.visible → sink),防回环.
  /// 阶段2 删除:改为 controls 内 AutoHide.visible 自驱鼠标隐藏 + 字幕 padding。
  void _syncVisible() {
    widget.visibleSink?.value = _autoHide.visible.value;
  }

  /// 切换全屏 — 双击与全屏按钮共用入口.
  ///
  /// 两步:① `actions.onToggleFullscreen` 同步 WindowService mode(守卫 + 鼠标
  /// 隐藏联动);② `state.toggleFullscreen()` 走 media_kit 原生 route
  /// (push/pop PageRouteBuilder)。用**本实例** [widget.state] — 窗口态
  /// isFullscreen()=false→enter, 全屏态 =true→exit, 自动正确分支
  /// (修复症状④退出渲染出错,见 memory [[project_fullscreen_minimal_fix]])。
  void _toggleFullscreen() {
    widget.actions.onToggleFullscreen?.call();
    widget.state.toggleFullscreen();
  }

  @override
  void initState() {
    super.initState();
    _isFullscreenNotifier = ValueNotifier<bool>(widget.state.isFullscreen());
    _autoHide = AutoHideController(
      vsync: this,
      // 阶段1:AutoHide 仍用 engine.state(阶段2 改 isPlaying)。
      engineState: widget.engine.state,
      isFullscreen: widget.state.isFullscreen(),
      popupCloseNotifier: _popupCloseNotifier,
    );
    _controlsState.init(); // 订阅 player.stream + 初始快照
    widget.engine.state.addListener(_onEngineStateChanged);
    _autoHide.init();

    // 创建共享 AnimationController — 初始 value=1.0(不 resize 时完全可见)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationNormal),
      value: 1.0,
    );
    _resizeOpacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    // 监听 resize 信号变化
    widget.resizing?.addListener(_onResizeChanged);
    // CB-06: 防御性同步 — widget 创建时 resizing 可能已为 true
    if (widget.resizing?.value == true) _onResizeChanged();

    // 同步控件可见性到外部 sink(全屏鼠标隐藏 + 字幕上移联动)
    _autoHide.visible.addListener(_syncVisible);
    _syncVisible(); // 立即同步初始状态
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
      _clickTimer = Timer(
        const Duration(milliseconds: _clickDelayMs),
        () {},
      );
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
      if (isIdle) {
        _animController.reverse(); // 恢复到 idle 装饰
      } else {
        _animController.forward(); // 恢复到 playing 装饰
      }
    }
  }

  void _onEngineStateChanged() {
    // resize 期间忽略 engine 状态变化,避免 controller 竞争(Pitfall 2)
    if (_isResizing) return;
    _autoHide.onEngineStateChanged();

    // engine 状态变化驱动 decoration 切换:idle→reverse(淡出),playing→forward(淡入)
    final isIdle = widget.engine.state.value == MediaState.idle;
    if (isIdle) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // VideoState 每次 builder 调用可能新实例 — 现取 isFullscreen 同步图标 + AutoHide。
    // 全屏态切换时 _isFullscreenNotifier 变化驱动 RightButtonGroup fullscreen_exit 图标。
    final fs = widget.state.isFullscreen();
    if (_isFullscreenNotifier.value != fs) {
      _isFullscreenNotifier.value = fs;
      _autoHide.isFullscreen = fs;
      _isFullscreenTransition = true; // 标记过渡,下次 isResizing=true 跳过 reverse()
    }
    // resizing 监听迁移 — 旧值移除,新值添加(CB-06: 同步当前值)
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_onResizeChanged);
      widget.resizing?.addListener(_onResizeChanged);
      _onResizeChanged();
    }
    // visibleSink 变化 — 立即同步一次到新 sink(listener 仍在 _autoHide.visible 上)
    if (oldWidget.visibleSink != widget.visibleSink) {
      _syncVisible();
    }
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.resizing?.removeListener(_onResizeChanged);
    _autoHide.visible.removeListener(_syncVisible);
    _clickTimer?.cancel();
    _popupCloseNotifier.dispose();
    _isFullscreenNotifier.dispose();
    _animController.dispose();
    _autoHide.dispose();
    _controlsState.dispose(); // 取消 stream 订阅 + dispose notifiers
    super.dispose();
  }

  /// 空状态页 — 仅 idle && !hasMedia 时渲染,IgnorePointer 透传让 ControlBar 可点。
  Widget _buildEmptyState(bool active) {
    if (!active) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: widget.openFileEnabled,
      builder: (_, enabled, _) => IgnorePointer(
        ignoring: !enabled,
        child: widget.emptyState!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 自驱动:builder 化后不依赖外层 ListenableBuilder,本控件自行监听
    // engine.state(算 isIdle + AutoHide decoration) + currentFileName(算 title)。
    // 注:position/isPlaying 等播放态走 _controlsState 的 ValueNotifier,ControlBar
    // 子组件各自 ValueListenableBuilder 监听,不触发本 ListenableBuilder 重建。
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.engine.state,
        widget.currentFileName,
      ]),
      builder: (context, _) {
        final isIdle = widget.engine.state.value == MediaState.idle;
        // emptyStatePresent 等价判定:idle && !hasMedia(hasMedia 依赖 currentFileName)
        final emptyActive =
            widget.emptyState != null && isIdle && !widget.engine.hasMedia;
        final fileName = widget.currentFileName.value;
        final title = fileName.isEmpty ? null : fileName;
        // idle + emptyState 时只对上方空白区域禁用手势,ControlBar 始终可交互
        final gestureActive = !emptyActive;
        // 路径B:vm 从 PlayerControlsState(player.stream)派生,非 engine。
        // isPlaying/position/duration/volume/rate 走 stream;isMuted 复用 engine;
        // 回调:onSeek/onPlayPause/onSetRate 直写 player(经 _controlsState),
        // onSetVolume/onToggleMute 走 engine(保 _preMuteVolume),
        // onSeekBack/onSeekForward 走 engine(语义糖,内部 seekTo→player.seek 一致)。
        final vm = ControlBarViewModel(
          isPlaying: _controlsState.isPlaying,
          position: _controlsState.positionMs,
          duration: _controlsState.durationMs,
          volume: _controlsState.volume01,
          isMuted: _controlsState.isMuted,
          rate: _controlsState.rate,
          isFullscreen: _isFullscreenNotifier,
          onSeek: _controlsState.seek,
          onPlayPause: _controlsState.playOrPause,
          onSeekBack: widget.engine.skipBack,
          onSeekForward: widget.engine.skipForward,
          onToggleMute: _controlsState.toggleMute,
          onSetVolume: _controlsState.setVolume,
          onSetRate: _controlsState.setRate,
        );
        return Stack(
          children: [
            // 最底层:空状态页(空状态时显示,在 ControlBar 之下)。
            if (widget.emptyState != null)
              Positioned.fill(child: _buildEmptyState(emptyActive)),
            // 手势区:单击/双击 — 仅覆盖 ControlBar 上方空白(不覆盖 ControlBar,
            // 按钮可点)。emptyActive 时 IgnorePointer 让下方空状态页收点击。
            Positioned.fill(
              bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: gestureActive ? _handleTap : null,
                child: IgnorePointer(
                  ignoring: emptyActive,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // 下层控制栏区域 — OSD / ControlBar / ErrorBanner 各自独立 Positioned,
            // 不再用单一 IgnorePointer 包裹整层(原方案在 visible=false 时连累
            // ErrorBanner 不可点 —— P3 根因)。
            RepaintBoundary(
              child: Stack(
                children: [
                  // OSD — 独立,不受控制栏可见性影响
                  Positioned(
                    bottom:
                        Tokens.controlBarMarginBottom +
                        Tokens.controlBarHeight +
                        12,
                    left: Tokens.controlBarMarginH,
                    right: Tokens.controlBarMarginH,
                    child: OsdOverlay(resizing: widget.resizing),
                  ),
                  // ControlBar — visible=false 时 Visibility 从 hit-test 树移除,
                  // 避免透明 ControlBar 抢点击;FadeTransition 仅驱动淡入/淡出动画。
                  ValueListenableBuilder<bool>(
                    valueListenable: _autoHide.visible,
                    builder: (_, isVisible, _) => Positioned(
                      left: Tokens.controlBarMarginH,
                      right: Tokens.controlBarMarginH,
                      bottom: Tokens.controlBarMarginBottom,
                      child: Visibility(
                        visible: isVisible,
                        maintainState: true,
                        maintainAnimation: true,
                        child: FadeTransition(
                          opacity: _autoHide.opacity,
                          child: ControlBar(
                            vm: vm,
                            actions: widget.actions,
                            playlist: widget.playlist,
                            playlistGeneration: widget.playlistGeneration,
                            isIdle: isIdle,
                            title: title,
                            opacity: _resizeOpacity,
                            enableBlur: isVisible,
                            decoration: _animController,
                            resizing: widget.resizing,
                            // 全屏切换 — 传 _toggleFullscreen 而非 actions.onToggleFullscreen:
                            // 需同时做 setMode 同步 + 本实例 state route 切换。
                            onToggleFullscreen: _toggleFullscreen,
                            // seek 钩子 — 拖动进度条期间冻结 auto-hide
                            onSeekStart: _autoHide.onSeekStart,
                            onSeekEnd: _autoHide.onSeekEnd,
                            // 音量等非 seek 子控件复用同一交互会话,避免各自维护 Timer。
                            onInteractionStart: _autoHide.onInteractionStart,
                            onInteractionEnd: _autoHide.onInteractionEnd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ErrorBanner — 独立可见且始终可点,不被控制栏可见性连累(P3 修复)
                  Positioned(
                    left: Tokens.controlBarMarginH + 16,
                    right: Tokens.controlBarMarginH + 16,
                    bottom:
                        Tokens.controlBarMarginBottom + Tokens.controlBarHeight + 8,
                    child: RepaintBoundary(
                      child: ErrorBanner(
                        engine: widget.engine,
                        onOpenFile: widget.actions.onOpenFile,
                        onRetry: widget.actions.onOpenFile,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 顶层:整区 MouseRegion — opaque=false 不阻止 ControlBar 收 tap/hover,
            // 但跟踪鼠标进出整个 Video。修复"鼠标从空白移到 ControlBar 触发 onExit
            // → 3s 后控件消失":整区覆盖 ControlBar,移入不 onExit,_hovering 保持 true。
            // onHover 仍仅底部 150px 唤起(保留用户"底部触发"意图);onEnter/onExit 整区。
            Positioned.fill(
              child: MouseRegion(
                opaque: false,
                hitTestBehavior: HitTestBehavior.translucent,
                onHover: (event) {
                  // D-03: 仅底部区域触发 — 鼠标在距底部 150px 内才唤起控制栏
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
          ],
        );
      },
    );
  }
}
