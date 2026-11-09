import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/services/playlist_coordinator.dart';
import '../../kernel/window_bridge/window_bridge.dart';
import '../dialogs/settings/settings_panel.dart';
import '../dialogs/settings/settings_panel_session.dart';
import 'auto_hide_controller.dart';
import 'controls_cursor_region.dart' show pointerInsideControlBar;
import 'controls_decoration_sync.dart';
import 'controls_derived_signals.dart';
import 'controls_host.dart';
import 'controls_keyboard.dart';
import 'controls_layers.dart';
import 'controls_listener_hub.dart';
import 'controls_scopes.dart';
import 'controls_subtitle_padding.dart';
import 'controls_tap_controller.dart';
import 'modal_hold_observer.dart';
import 'mpv_kit_player_port.dart';
import 'panel_workspace_controller.dart';
import 'player_actions.dart';
import 'player_controls_state.dart';
import 'workspace_focus_scope.dart';
import 'workspace_menu_session.dart';

/// 控制层 widget — 数据源直连视频控制端口 [VideoControlsPort].
///
/// 控制层由 Stack 组合空状态、控制栏、错误提示和鼠标唤起区域:
/// - 播放/位置/时长/倍速(读): [PlayerControlsState] 订阅 `player.stream`
/// - 播放/暂停、快退、快进(写): 经 [PlayerActions] 进入 PlaybackController 门面
/// - 进度条 seek/倍速(写): 经端口直写 `player`，保留低延迟精细交互
/// - 音量/静音(读写): 走 [MediaEngine] 单一数据源(感知曲线 + 原生静音,
///   v0.0.8.1 — 双源线性换算会使滑条漂移到 mpv 立方空间)
/// - isFullscreen: 由 [WindowMode] 单一数据源驱动(图标/auto-hide/cursor/
///   ESC)，全屏由窗口模式驱动原生窗口，无独立 route。
///
/// 设计要点:
/// - **AutoHide 改 isPlaying**:[PlayerControlsState.isPlaying] 驱动,静置照常隐藏
///   (v0.0.6 追加 pinned 语义: 空置态钉住常显, 见 [_syncAutoHidePinned])
/// - **字幕 padding**:由本控件监听 [_autoHide.visible] 调
///   `widget.video.setSubtitleViewPadding`，控制栏显隐时字幕上下避让
/// - **键盘住进 controls**:[Focus] + autofocus + onKeyEvent 最小集(ESC/F/Space/
///   方向键)
/// - **MouseRegion cursor**:全屏 + 控件隐藏 → none(沉浸)
class PlayerVideoControls extends StatefulWidget {
  /// 视频控制端口；生产环境为 [MpvKitVideoControlsPort]，
  /// 测试可注入不加载原生库的 fake。
  final VideoControlsPort video;

  final MediaEngine engine;
  final PlayerActions actions;

  /// 活动文件名 — 驱动 ControlBar 标题 + 空状态判定(hasMedia 依赖它)。
  final ValueListenable<String> currentFileName;

  /// 完整媒体身份，不用可能重名的显示标题判断旧媒体菜单失效。
  final ValueListenable<String?>? mediaIdentity;

  /// 空状态页 — 空状态(idle && !hasMedia)时在 Stack 最底层渲染。
  final Widget? emptyState;

  /// 窗口模式单一数据源 — 驱动全屏按钮图标、auto-hide 延迟、cursor 与 ESC。
  ///
  /// 窗口态与全屏 route 的 controls 实例监听同一 mode,进出全屏时 setMode
  /// 必然提交状态,图标/标题栏/cursor 同步还原,不依赖 Video 重建时序。
  final ValueListenable<WindowMode> windowMode;

  /// 播放列表面板可见性 (v0.0.5) — 宿主持有的共享 notifier.
  ///
  /// 面板住进控制层，与控制栏同机制随窗口/全屏显示;
  /// null 时面板整体不挂载(测试退路).
  final ValueNotifier<bool>? playlistVisible;

  /// 播放列表协调器 — 面板数据源与动作入口。null 时面板不挂载.
  final PlaylistCoordinator? playlistCoordinator;

  /// 设置面板可见性 — 宿主持有的共享 notifier.
  ///
  /// 与 [playlistVisible] 同构:面板住进 controls builder(全屏 route 自动
  /// 携带),共享 notifier 使窗口态/全屏两实例状态同步。null 时不挂载
  /// (测试退路)。
  final ValueNotifier<bool>? settingsVisible;

  /// 设置服务集合 (v0.0.6) — 断点续播开关等面板门控数据源.
  final SettingsServicesBundle? settingsServices;

  /// 跨全屏共享的角色与展示数据；本实例仍拥有临时焦点。
  final PanelWorkspaceController? workspace;
  final SettingsPanelSession? settingsSession;
  final WorkspaceMenuSession? menuSession;

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
    this.mediaIdentity,
    this.playlistVisible,
    this.settingsVisible,
    this.playlistCoordinator,
    this.settingsServices,
    this.workspace,
    this.settingsSession,
    this.menuSession,
    this.emptyState,
    this.resizing,
    this.onBuild,
  });

  /// 控制栏显现判定 — 指针是否落在控制栏自身的矩形内 (实现见
  /// [pointerInsideControlBar])；保留为静态入口供测试与外部引用。
  @visibleForTesting
  static bool isPointerInsideControlBar(Size area, Offset localPosition) =>
      pointerInsideControlBar(area, localPosition);

  @override
  State<PlayerVideoControls> createState() => _PlayerVideoControlsState();
}

/// [PlayerVideoControls] 的编排 State — 只负责生命周期、状态联动与组装。
///
/// 具体职责分拆在同目录各文件: 监听聚合 ([ControlsListenerHub])、字幕安全区
/// ([SubtitlePaddingSync])、键盘/全屏命令 ([ControlsCommands])、点击语义
/// ([ControlsTapController])、光标/语义派生信号 ([ControlsDerivedSignals])。
class _PlayerVideoControlsState extends State<PlayerVideoControls>
    with TickerProviderStateMixin
    implements ControlsHost {
  // 下列 late final 依赖 widget 或 `this`(vsync/host)，字段初始化器无法引用
  // 实例成员，故在 initState 内一次性初始化，此后不再变更。

  /// 路径B 核心:从当前 route 的视频端口订阅 Player stream。全屏 route 复用
  /// 同一个 Player，但每个 controls 实例独立维护展示状态与生命周期。
  late final PlayerControlsState _controlsState;

  /// 控制栏自动隐藏 (需要 ticker)。
  late final AutoHideController _autoHide;

  late final ControlsDecorationSync _decor;
  late final ControlsCommands _commands;
  late final ControlsTapController _tap;
  late final ControlsDerivedSignals _derived;
  late final SubtitlePaddingSync _subtitle;

  final _hub = ControlsListenerHub();
  final _popupCloseNotifier = ValueNotifier<int>(0);

  /// controls 自带 FocusNode + autofocus，全屏 route 复制 builder 时自动携带
  /// (项目 `Video` 未传 focusNode，全屏 route 不自带 Focus 键盘事件收不到)。
  final _focusNode = FocusNode();

  /// seek 拖动挂起信号 (v0.0.8.2) — 拖进度条期间玻璃模糊短暂停用。
  /// 信号源是 ProgressBar 的 onSeekStart/onSeekEnd 链（非 engine.isSeeking，
  /// 后者拖动中高频抖动且不覆盖 seek-hold 尾窗）。
  final _seekScrubbing = ValueNotifier<bool>(false);

  /// deactivate 标记 — 挡 LayoutBuilder 在 inactive element 上触发的
  /// didUpdateWidget/build 查祖先(会断言)。State.mounted 在此窗口内无效。
  bool _isDeactivating = false;

  /// 上一次 legacy 设置可见性 — 焦点归还的边沿检测基准。
  bool _lastSettingsVisible = false;

  /// 本 route 的焦点注册表 — 仅在 workspace 非空时创建。
  @override
  WorkspaceFocusRegistry? workspaceFocus;

  // ---- ControlsHost: 命令/点击控制器读取最新 widget 数据 ----
  @override
  VideoControlsPort get video => widget.video;
  @override
  MediaEngine get engine => widget.engine;
  @override
  PlayerActions get actions => widget.actions;
  @override
  ValueListenable<WindowMode> get windowMode => widget.windowMode;
  @override
  WorkspaceMenuSession? get menuSession => widget.menuSession;
  @override
  PanelWorkspaceController? get workspace => widget.workspace;
  @override
  ValueNotifier<bool>? get playlistVisible => widget.playlistVisible;
  @override
  ValueListenable<bool>? get resizing => widget.resizing;
  @override
  AutoHideController get autoHide => _autoHide;
  @override
  bool get isAlive => mounted && !_isDeactivating;

  /// legacy 设置可见性 — 工作区接管可见性与焦点后恒为 null。
  @override
  ValueNotifier<bool>? get legacySettingsVisible =>
      widget.workspace == null ? widget.settingsVisible : null;

  @override
  void initState() {
    super.initState();
    // _controlsState.init() 前置 — isPlaying 有真值后再构造 _autoHide
    // (AutoHide 监听 isPlaying，init() 读初值)。
    _controlsState = PlayerControlsState(
      widget.video.player,
      engine: widget.engine,
    )..init(); // 订阅 player.stream + 初始快照
    _decor = ControlsDecorationSync(
      this,
      vsync: this,
      onResizeSettled: _syncAutoHidePinned,
    )..init(); // 单一数据源：初始值与后续变化都来自 windowMode
    _autoHide = AutoHideController(
      vsync: this,
      isPlaying: _controlsState.isPlaying,
      // 隐藏延迟由 mode 决定(全屏 3s/窗口态 5s)，与图标同源。
      isFullscreen: _decor.isFullscreen.value,
      popupCloseNotifier: _popupCloseNotifier,
    )..init();
    _commands = ControlsCommands(this);
    _tap = ControlsTapController(
      this,
      toggleFullscreen: _commands.toggleFullscreen,
    );
    _derived = ControlsDerivedSignals(this);
    _subtitle = SubtitlePaddingSync(
      readVideo: () => widget.video,
      barVisible: _autoHide.visible,
      canWrite: () => isAlive,
    );
    _syncAutoHidePinned(); // v0.0.6: 空置态应用启动即钉住控制栏。
    _bindSources();
    _hub.attach();
    _lastSettingsVisible = legacySettingsVisible?.value ?? false;
    _syncAutoHideHold(); // attach 即同步一次 (先开窗后进全屏的时序)。
    _derived.recompute();
    // CB-06: 防御性同步 — widget 创建时 resizing 可能已为 true。
    if (widget.resizing?.value ?? false) _decor.onResizeChanged();
    // 字幕 padding 自驱；post-frame 确保端口已挂载。
    _subtitle.schedule();
  }

  /// 单一注册路径 — initState 与 didUpdateWidget 共用，幂等。
  ///
  /// 返回源发生变化的槽位集合，供 didUpdateWidget 做迁移后的补同步。
  Set<ControlsSlot> _bindSources() {
    final w = widget;
    final legacy = legacySettingsVisible;
    final changed = <ControlsSlot>{};
    void bind(ControlsSlot s, List<Listenable?> src, VoidCallback cb) {
      if (_hub.bind(s, src, cb)) changed.add(s);
    }

    bind(ControlsSlot.engineState, [w.engine.state], _onEngineStateChanged);
    bind(ControlsSlot.mode, [w.windowMode], _decor.syncMode);
    bind(ControlsSlot.resize, [w.resizing], _decor.onResizeChanged);
    bind(ControlsSlot.subtitle, [_autoHide.visible], _subtitle.schedule);
    // v0.0.5: auto-hide hold 多源合成 — 模态/播放列表/任务面板/菜单任一变化
    // 即同步；合并为一个监听，不再对 5 个 notifier 各挂一份。
    bind(ControlsSlot.hold, [
      ModalHoldObserver.openModalCount,
      w.playlistVisible,
      legacy,
      w.workspace,
      w.menuSession,
    ], _syncAutoHideHold);
    bind(ControlsSlot.media, [
      w.mediaIdentity ?? w.currentFileName,
    ], _onMediaIdentityChanged);
    // E1 焦点归还 — 关面板时显式把焦点还给控制层。
    bind(ControlsSlot.settingsFocus, [legacy], _handleSettingsVisibleChanged);
    bind(ControlsSlot.derived, [
      _autoHide.visible,
      w.windowMode,
      w.playlistVisible,
      w.workspace,
      legacy,
      w.menuSession,
      w.resizing,
    ], _derived.recompute);
    return changed;
  }

  @override
  void didUpdateWidget(covariant PlayerVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 阶段3 bug1 教训：route pop 期间 element inactive(mounted 仍 true)，
    // 祖先查询会断言 — _isDeactivating 守卫保留。全屏状态由 windowMode 单一
    // 数据源驱动，经 _decor.syncMode 同步图标 + AutoHide + 过渡标记。
    if (!_isDeactivating) _decor.syncMode();
    if (oldWidget.video != widget.video || oldWidget.engine != widget.engine) {
      _migrateSources(oldWidget);
    }
    final changed = _bindSources();
    // engine 更换：同步局部 idle 信号，避免沿用旧引擎状态。
    if (changed.contains(ControlsSlot.engineState)) {
      _decor.refreshIdle();
    }
    // resizing 源更换：inactive 期间只更新 source，activate 再统一连接。
    if (changed.contains(ControlsSlot.resize) && _hub.isAttached) {
      _decor.onResizeChanged();
    }
    if (changed.contains(ControlsSlot.settingsFocus)) {
      _lastSettingsVisible = legacySettingsVisible?.value ?? false;
    }
    _syncAutoHideHold();
    _derived.recompute();
  }

  /// 视频端口或引擎更换时迁移控制状态，避免新外壳继续驱动旧数据源。
  void _migrateSources(PlayerVideoControls old) {
    _controlsState.updateSources(widget.video.player, engine: widget.engine);
    // 只有端口更换时基础 padding 才失效；仅换 engine 时复用同一端口，避免把
    // 已加过的 control bar inset 再次当作基础值。
    if (old.video != widget.video) _subtitle.resetForNewPort();
    // active replacement 不一定伴随显隐/resize/engine 变化，须立即把当前
    // 可见性同步到新端口；inactive 阶段延迟到 activate。
    if (!_isDeactivating) _subtitle.schedule();
  }

  @override
  void deactivate() {
    _isDeactivating = true;
    // deactivate 即断开外部 listener — _autoHide 的 timer/动画在
    // deactivate→dispose 之间仍可能触发 visible 变化，进而写已 deactivate 的
    // 视频端口 → 查 deactivated ancestor 断言；dispose 太晚。reparent 由
    // activate() 统一恢复。
    _hub.detach();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isDeactivating = false;
    _hub.attach();
    _decor.onResizeChanged();
    _decor.refreshIdle();
    // engine 实例可能被替换(测试) — 空置态重新判定钉住 (v0.0.6)。
    _syncAutoHidePinned();
    // activate 视为新写入契约起点 (reparent 后端口可能全新)：空写守卫复位。
    _subtitle.resetGuard();
    _subtitle.schedule();
  }

  @override
  void dispose() {
    _hub.detach();
    _tap.dispose();
    _focusNode.dispose();
    _popupCloseNotifier.dispose();
    _decor.dispose();
    _seekScrubbing.dispose();
    _derived.dispose();
    _autoHide.dispose();
    _controlsState.dispose(); // 取消 stream 订阅 + dispose notifiers
    super.dispose();
  }

  void _onEngineStateChanged() {
    // resize 期间忽略 engine 状态变化，避免 controller 竞争(Pitfall 2)。
    // AutoHide 自监听 isPlaying(player.stream 驱动)，此处只驱动 decoration。
    if (!_decor.onEngineStateChanged()) return;
    _syncAutoHideHold();
    // v0.0.6: 空置态钉住同步 (stop→idle+无媒体 ⇒ 钉住; 开始播放 ⇒ 解除)。
    _syncAutoHidePinned();
  }

  /// 控制栏自动隐藏 hold 多源合成 — 任一为真即冻结隐藏计时:
  /// ① 模态弹层 ② 播放列表面板可见 ③ 任务面板(设置)可见 ④ 自有菜单。
  void _syncAutoHideHold() {
    _autoHide.modalOpen =
        ModalHoldObserver.openModalCount.value > 0 || anyPanelOpen;
  }

  /// 空置态钉住控制栏 (v0.0.6) — 条件与空置页渲染条件完全一致 (emptyState
  /// 非空 && idle && !hasMedia)：空置页只有"打开文件"按钮，控制栏是播放列表/
  /// 设置/全屏的唯一入口，自动隐藏会让它们全部不可达。emptyState 为 null
  /// (测试装配) 恒不钉住。
  void _syncAutoHidePinned() {
    _autoHide.pinned =
        widget.emptyState != null &&
        widget.engine.state.value == MediaState.idle &&
        !widget.engine.hasMedia;
  }

  /// 媒体更新只失效媒体绑定菜单，工作区角色与设置会话保持不变。
  void _onMediaIdentityChanged() => widget.menuSession?.mediaChanged(
    widget.mediaIdentity?.value ?? widget.currentFileName.value,
  );

  /// 设置面板关闭时归还焦点（E1）— `FocusNode.unfocus()` 会把焦点落到路由级
  /// scope，全屏 route 无 KeyboardHandler 兜底按键全聋；故在翻 false 的边沿
  /// 显式 requestFocus 回控制层（唯一焦点写入点，无双重 mark 竞态）。
  void _handleSettingsVisibleChanged() {
    final value = legacySettingsVisible?.value ?? false;
    if (!value && _lastSettingsVisible && isAlive) _focusNode.requestFocus();
    _lastSettingsVisible = value;
  }

  /// workspace 变化时重建本 route 的焦点注册表 (共享工作区绝不存 FocusNode)。
  void _ensureFocusRegistry() {
    final shared = widget.workspace;
    if (shared != null && workspaceFocus?.controller != shared) {
      workspaceFocus = WorkspaceFocusRegistry(
        controller: shared,
        player: _focusNode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 仅测试观测外层 build；状态监听已下沉到各子 widget 内的局部区域。
    widget.onBuild?.call();
    _ensureFocusRegistry();
    return ControlsScopes(
      menuSession: widget.menuSession,
      focusRegistry: workspaceFocus,
      onEscape: _commands.exitFullscreen,
      // null resize 源(测试注入) = 裸树，保留既有语义断言。
      semanticsExcluded: widget.resizing == null
          ? null
          : _derived.semanticsExcluded,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _commands.handleKey,
        child: ControlsLayers(
          config: widget,
          controlsState: _controlsState,
          autoHide: _autoHide,
          decoration: _decor.decoration,
          isFullscreen: _decor.isFullscreen,
          isIdle: _decor.isIdle,
          scrubbing: _seekScrubbing,
          cursorHidden: _derived.cursorHidden,
          tap: _tap,
          workspaceFocus: workspaceFocus,
          panelSources: [
            widget.workspace,
            legacySettingsVisible,
            widget.menuSession,
            widget.playlistVisible,
          ],
          anyPanelOpen: () => anyPanelOpen,
          onToggleFullscreen: _commands.toggleFullscreen,
        ),
      ),
    );
  }
}
