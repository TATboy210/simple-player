import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// services: KeyDownEvent / LogicalKeyboardKey / KeyEventResult / FocusNode
// (material.dart 不完整导出 services 的键盘事件类型)
import 'package:flutter/services.dart';
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
}) {
  return PlayerVideoControls(
    video: MediaKitVideoControlsPort(state),
    engine: engine,
    actions: actions,
    playlist: playlist,
    playlistGeneration: playlistGeneration,
    currentFileName: currentFileName,
    openFileEnabled: openFileEnabled,
    emptyState: emptyState,
    resizing: resizing,
  );
}

/// 路径B 控制栏 widget — 数据源直连 media_kit [Player.stream]。
///
/// 与 [ControlsOverlay] 同构 Stack(空状态→RepaintBoundary[OsdOverlay+ControlBar
/// +ErrorBanner]→MouseRegion 唤起),差异仅在数据源/控制出口:
/// - 播放/位置/时长/倍速/音量(读): [PlayerControlsState] 订阅 `player.stream`
/// - 播放/暂停、快退、快进(写): 经 [PlayerActions] 进入 PlaybackController 门面
/// - 进度条 seek/倍速(写): 经 [PlayerPort] 直写 `player`，保留低延迟精细交互
/// - 音量/静音(写): 走 [MediaEngine](保 `_preMuteVolume` 语义)
/// - isFullscreen: 从 [VideoState.isFullscreen] 现取(每实例独立,修复"图标不动态")
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

  const PlayerVideoControls({
    super.key,
    required this.video,
    required this.engine,
    required this.actions,
    required this.currentFileName,
    required this.playlist,
    required this.playlistGeneration,
    required this.openFileEnabled,
    this.emptyState,
    this.resizing,
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

  /// 派生 isFullscreen — 同步 widget.video.isFullscreen,供全屏按钮图标动态切换。
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

  /// 阶段3 bug1:deactivate 标记 — 挡 LayoutBuilder 在 inactive element 上触发
  /// 的 didUpdateWidget/build 查 isFullscreen(查 ancestor 会断言)。
  /// deactivate() 即置 true(element 仍 mounted 但 inactive,State.mounted 无效)。
  bool _isDeactivating = false;

  /// 对齐 media_kit 原生 onTapUp 400ms 双击窗口(同 [ControlsOverlay._clickDelayMs])。
  /// 本类自带副本 — _clickDelayMs 在 ControlsOverlay 是 private,跨文件不可访问;
  /// 阶段3 删 ControlsOverlay 后此常量成为唯一来源。
  static const _clickDelayMs = 400;

  /// 切换全屏 — 双击与全屏按钮共用入口.
  ///
  /// 两步:① `actions.onToggleFullscreen` 同步 WindowService mode(守卫 + 鼠标
  /// 隐藏联动);② `state.toggleFullscreen()` 走 media_kit 原生 route
  /// (push/pop PageRouteBuilder)。用**本实例** [widget.video] — 窗口态
  /// isFullscreen()=false→enter, 全屏态 =true→exit, 自动正确分支
  /// (修复症状④退出渲染出错,见 memory [[project_fullscreen_minimal_fix]])。
  void _toggleFullscreen() {
    widget.actions.onToggleFullscreen?.call();
    widget.video.toggleFullscreen();
  }

  /// 阶段2:字幕 padding 自驱 — 监听 [_autoHide.visible] 调本实例 VideoState.
  ///
  /// 修"自动隐藏失效"根因:旧路径 PlayerScreen._onControlsVisibleChanged 用窗口态
  /// `_videoKey.currentState` 调 setSubtitleViewPadding,全屏 route 时全屏 VideoState
  /// 是另一实例,padding 调错对象 → 字幕被控制栏遮挡/控件隐藏字幕不动。本控件每实例
  /// 监听自己 _autoHide.visible,调 `widget.video`(本实例)→ 双实例各自正确。
  void _syncSubtitlePadding() {
    // 阶段3:退出全屏 route pop(Duration.zero) 后,全屏 VideoState deactivate/dispose。
    // post-frame callback(line 413) 或 _autoHide.visible listener 可能在本控件
    // 失效后触发本方法,调用已 deactivate 的 widget.video.setSubtitleViewPadding
    // 会更新 media_kit _videoViewParametersNotifier → 触发全屏 Video rebuild →
    // 查已 deactivate 的 InheritedWidget ancestor → "deactivated widget's
    // ancestor" 断言(framework.dart:6417)。mounted 挡本控件 dispose 后;
    // widget.video.isMounted 挡全屏 VideoState dispose 后。
    if (!mounted || !widget.video.isMounted) return;
    final videoState = widget.video;
    final base = videoState.subtitlePadding;
    if (_autoHide.visible.value) {
      videoState.setSubtitleViewPadding(
        base +
            const EdgeInsets.only(
              bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
            ),
      );
    } else {
      videoState.setSubtitleViewPadding(base);
    }
  }

  /// 阶段2:键盘事件处理 — controls 内 Focus 最小集.
  ///
  /// 全屏 route 复制 builder 时自动携带(KeyboardHandler 在 builder 外不进 route)。
  /// 最小集:ESC(退出全屏)/F(切换全屏)/Space(播放暂停)/←→(seek ±5s)。
  /// 其余键(N/P/O/S/M/[]/F1/媒体键)return ignored 冒泡给窗口态 KeyboardHandler
  /// (全屏 route 缺这些键 — 已知限制,计划 line 85 认可)。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      // ESC:仅全屏态退出(窗口态 ESC 冒泡给 KeyboardHandler 关播放列表/设置)
      if (widget.video.isFullscreen) {
        widget.actions.onToggleFullscreen?.call();
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
    _isFullscreenNotifier = ValueNotifier<bool>(widget.video.isFullscreen);
    // 阶段2:_controlsState.init() 前置 — isPlaying 有真值后再构造 _autoHide
    // (AutoHide 监听 _controlsState.isPlaying,init() 读初值)。
    _controlsState.init(); // 订阅 player.stream + 初始快照
    _autoHide = AutoHideController(
      vsync: this,
      // 阶段2:AutoHide 用 _controlsState.isPlaying(player.stream 驱动)。
      isPlaying: _controlsState.isPlaying,
      isFullscreen: widget.video.isFullscreen,
      popupCloseNotifier: _popupCloseNotifier,
    );
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

    // 阶段2:字幕 padding 自驱(每实例调自己 VideoState)。post-frame 确保
    // widget.video 已挂载(setSubtitleViewPadding 需 VideoState 已构建)。
    _autoHide.visible.addListener(_syncSubtitlePadding);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSubtitlePadding());
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
    // 阶段2:AutoHide 自动监听 _controlsState.isPlaying(player.stream 驱动),
    // 不需手动调 _autoHide.onEngineStateChanged()。本回调仅驱动 decoration 切换。

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
    // 阶段3 bug1 真正根因(实机 stack trace #6 line 502 定位,前三次修复无效):
    // 退出全屏 route pop(Duration.zero) 过程中,全屏 VideoState 的 element 进入
    // inactive lifecycle(deactivate 已调,dispose 未调)。全屏 Video 内部的
    // LayoutBuilder 在 pop 时序的 layout 阶段触发 _rebuildWithConstraints
    // (layout 阶段不检查子 element active 状态),rebuild 传播到本控件
    // didUpdateWidget,此时 widget.video.isFullscreen → VideoState.isFullscreen
    // → FullscreenInheritedWidget.maybeOf → dependOnInheritedWidgetOfExactType
    // 在 inactive element 上查 ancestor → framework.dart:5082 断言。
    //
    // 为什么前三次修复无效(关键教训):
    // ①0ff3859 deactivate() 移除 listener — 挡不住本崩点。didUpdateWidget 由
    //   LayoutBuilder rebuild 触发(非 notifier listener),deactivate 移除的
    //   engine.state/resizing/_autoHide.visible listener 与此路径无关。
    // ②mounted guard 无效 — State.mounted = (_element != null),_element 只在
    //   unmount() 置 null,deactivate 不动 → deactivate 后 mounted 仍 true →
    //   guard 通过 → 崩。mounted 与 active 不同步。
    // ③Element.active — 非 public getter(dart analyze undefined),不可用。
    //
    // 真正修复:_isDeactivating flag。deactivate() 即置 true(stack trace 证明
    // didUpdateWidget 在 deactivate 之后触发,此时 element inactive),didUpdateWidget
    // /build 检查 flag 跳过 isFullscreen 查询。本控件不 reparent,无需 activate 重置。
    // resizing 监听迁移不跳过(漏移除 oldWidget.resizing 会泄漏)。
    if (!_isDeactivating) {
      // VideoState 每次 builder 调用可能新实例 — 现取 isFullscreen 同步图标 + AutoHide。
      // 全屏态切换时 _isFullscreenNotifier 变化驱动 RightButtonGroup fullscreen_exit 图标。
      final fs = widget.video.isFullscreen;
      if (_isFullscreenNotifier.value != fs) {
        _isFullscreenNotifier.value = fs;
        _autoHide.isFullscreen = fs;
        _isFullscreenTransition = true; // 标记过渡,下次 isResizing=true 跳过 reverse()
      }
    }
    // resizing 监听迁移 — 旧值移除,新值添加(CB-06: 同步当前值)
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_onResizeChanged);
      widget.resizing?.addListener(_onResizeChanged);
      _onResizeChanged();
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
    // no-op)。注:本控件由 controls builder 构建,不 reparent,无需 activate 重 add。
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.resizing?.removeListener(_onResizeChanged);
    _autoHide.visible.removeListener(_syncSubtitlePadding);
    super.deactivate();
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.resizing?.removeListener(_onResizeChanged);
    _autoHide.visible.removeListener(_syncSubtitlePadding);
    _clickTimer?.cancel();
    _focusNode.dispose();
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
        // emptyState 契约非空, `?? SizedBox.shrink()` 防御性兜底消除 `!`
        child: widget.emptyState ?? const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 阶段2:Focus 包裹整个 controls — autofocus 让 controls 挂载即获焦,
    // onKeyEvent 处理最小集(ESC/F/Space/方向键),其余冒泡窗口态 KeyboardHandler。
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ListenableBuilder(
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
          // 路径B:展示数据从 PlayerControlsState(player.stream)派生；基础播放
          // 命令经稳定 PlayerActions 进入 PlaybackController，seek-hold/倍速仍保留
          // 直达 player 的精细交互路径，音量/静音继续走 engine。
          final onPlayPause = widget.actions.onPlayPause;
          final onSeekBack = widget.actions.onSeekBack;
          final onSeekForward = widget.actions.onSeekForward;
          final vm = ControlBarViewModel(
            isPlaying: _controlsState.isPlaying,
            position: _controlsState.positionMs,
            duration: _controlsState.durationMs,
            volume: _controlsState.volume01,
            isMuted: _controlsState.isMuted,
            rate: _controlsState.rate,
            isFullscreen: _isFullscreenNotifier,
            onSeek: _controlsState.seek,
            onPlayPause: onPlayPause ?? () {},
            onSeekBack: onSeekBack ?? (_) {},
            onSeekForward: onSeekForward ?? (_) {},
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
                          key: const Key('player-controls-visibility'),
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
                          Tokens.controlBarMarginBottom +
                          Tokens.controlBarHeight +
                          8,
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
              //
              // 阶段2:cursor 由本控件 _autoHide.visible 驱动(替代旧 PlayerScreen
              // _controlsVisible 跨层) — 全屏 + 控件隐藏 → none(沉浸鼠标)。
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _autoHide.visible,
                  builder: (_, isVisible, _) => MouseRegion(
                    opaque: false,
                    hitTestBehavior: HitTestBehavior.translucent,
                    // 全屏 + 控件隐藏 → 隐藏鼠标(沉浸);否则 defer(窗口态/控件可见)
                    // 阶段3:_isDeactivating flag 挡 widget.video deactivate 时序
                    // (mounted 无效、Element.active 非 public;详见 didUpdateWidget 注释)。
                    // build 同 didUpdateWidget 可能在 LayoutBuilder layout 阶段被触发。
                    cursor:
                        !_isDeactivating &&
                            widget.video.isFullscreen &&
                            !isVisible
                        ? SystemMouseCursors.none
                        : MouseCursor.defer,
                    onHover: (event) {
                      // D-03: 仅底部区域触发 — 鼠标在距底部 150px 内才唤起控制栏
                      final size = context.size;
                      if (size == null) return;
                      final mouseFromBottom =
                          size.height - event.localPosition.dy;
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
          );
        },
      ),
    );
  }
}
