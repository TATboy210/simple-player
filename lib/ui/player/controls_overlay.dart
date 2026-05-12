import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import 'control_bar.dart';
import 'error_banner.dart';

/// 控制栏容器 — 鼠标移动时显示，静止后自动隐藏
///
/// 手势统一处理：单击空白区域隐藏控制栏，双击切换全屏。
/// ControlBar 按钮通过子 GestureDetector 优先赢得手势竞技场，不触发隐藏。
class ControlsOverlay extends StatefulWidget {
  static const _clickDelayMs = 250; // 等待可能的双击
  final MediaEngine engine;
  final bool isFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlayMode;
  final IconData? playModeIcon;
  final bool playModeActive;

  /// 播放模式名称（如"顺序播放"、"列表循环"）
  final String? playModeLabel;

  /// 是否为视频媒体（影响 prev/next 按钮的 tooltip）
  final bool isVideo;

  /// 空状态存在时，控制栏不拦截 hit test（让下层 EmptyState 按钮可点击）
  final bool emptyStatePresent;

  const ControlsOverlay({
    super.key,
    required this.engine,
    this.isFullscreen = false,
    this.onPrevious,
    this.onNext,
    this.onTogglePlaylist,
    this.onSettings,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onTogglePlayMode,
    this.playModeIcon,
    this.playModeActive = false,
    this.playModeLabel,
    this.isVideo = false,
    this.emptyStatePresent = false,
  });

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacity;
  bool _visible = true;
  bool _hovering = false;
  Timer? _hideTimer;
  Timer? _clickTimer;

  // OSD 状态
  late final AnimationController _osdAnim;
  String _osdMessage = '';
  int _osdGeneration = 0;

  /// 节流：避免每次 hover 像素都触发 setState
  DateTime _lastHoverTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _hoverThrottle = Duration(milliseconds: 100);

  /// 全屏 3s，窗口化 5s
  Duration get _hideDelay => widget.isFullscreen
      ? const Duration(seconds: Tokens.hideDelayFullscreen)
      : const Duration(seconds: Tokens.hideDelayWindowed);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationFade),
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _osdAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // 监听 state 变化，暂停/停止/完成/错误时强制显示（在 listener 中处理，不在 build 中）
    widget.engine.state.addListener(_onEngineStateChanged);
    widget.engine.volume.addListener(_onVolumeChanged);
    widget.engine.isMuted.addListener(_onVolumeChanged);
    // idle 时显示控制栏（永久显示，不自动隐藏）
    if (widget.engine.state.value == MediaState.idle) {
      _visible = true;
      _animController.value = 1;
    } else {
      _scheduleHide();
    }
  }

  /// 单击空白区域 → 隐藏控制栏（250ms 延迟等待可能的双击）
  void _handleTap() {
    _clickTimer?.cancel();
    _clickTimer = Timer(
      const Duration(milliseconds: ControlsOverlay._clickDelayMs),
      () {
        if (!mounted) return;
        if (widget.engine.state.value == MediaState.idle) return;
        if (_visible) _hide();
      },
    );
  }

  /// 双击 → 切换全屏
  void _handleDoubleTap() {
    _clickTimer?.cancel();
    widget.onToggleFullscreen?.call();
  }

  void _onEngineStateChanged() {
    if (!mounted) return;
    final s = widget.engine.state.value;
    // idle（未加载媒体）时永久显示控制栏，不自动隐藏
    if (s == MediaState.idle) {
      _hideTimer?.cancel();
      if (!_visible) {
        _show();
      }
      return;
    }
    // loading/playing: 显示控制栏并启动自动隐藏
    if (s == MediaState.loading || s == MediaState.playing) {
      if (!_visible) {
        _show();
        _scheduleHide();
      }
      return;
    }
    // paused/stopped/completed/error: 强制显示，不自动隐藏
    final alwaysShow =
        s == MediaState.paused ||
        s == MediaState.stopped ||
        s == MediaState.completed ||
        s == MediaState.error;
    if (alwaysShow && !_visible) {
      _show();
      _hideTimer?.cancel(); // 取消 hide timer，防止闪烁
    }
  }

  /// 取消旧 Timer 再设新的，避免多次鼠标移动导致 Timer 堆积
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && !_hovering) _hide();
    });
  }

  void _show() {
    if (!mounted) return;
    if (!_visible) {
      setState(() => _visible = true);
      _animController.forward();
    }
  }

  void _hide() {
    // idle 时控制栏永久显示，不允许隐藏
    if (widget.engine.state.value == MediaState.idle) return;
    if (_visible && !_hovering) {
      _animController.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  void _onMouseMove() {
    // idle 时控制栏永久显示，不响应鼠标移动
    if (widget.engine.state.value == MediaState.idle) return;
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottle) return;
    _lastHoverTime = now;
    _show();
    _scheduleHide();
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.engine.volume.removeListener(_onVolumeChanged);
    widget.engine.isMuted.removeListener(_onVolumeChanged);
    _hideTimer?.cancel();
    _clickTimer?.cancel();
    _osdAnim.dispose();
    _animController.dispose();
    super.dispose();
  }

  // OSD 逻辑 — 监听音量/静音变化，显示浮动提示
  String get _osdKey =>
      '${widget.engine.isMuted.value}_${(widget.engine.volume.value * 100).round()}';

  late String _lastOsdKey = _osdKey;

  void _onVolumeChanged() {
    final key = _osdKey;
    if (key == _lastOsdKey) return;
    _lastOsdKey = key;
    final engine = widget.engine;
    final l10n = AppLocalizations.of(context);
    if (engine.isMuted.value) {
      _showOsd(l10n.mute);
    } else {
      _showOsd(l10n.volumePercent('${(engine.volume.value * 100).round()}'));
    }
  }

  void _showOsd(String message) {
    _osdAnim.stop();
    _osdAnim.reset();
    final gen = ++_osdGeneration;
    setState(() => _osdMessage = message);
    _osdAnim.forward().then((_) {
      Future.delayed(
        const Duration(seconds: 1),
        () {
          if (!mounted || gen != _osdGeneration) return;
          _osdAnim.reverse();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = widget.engine.state.value == MediaState.idle;
    // 手势统一在此处理：
    // - 单击空白区域 → 隐藏控制栏
    // - 双击 → 切换全屏
    // - ControlBar 按钮有自己的 GestureDetector，优先赢得竞技场，不触发隐藏
    // - behavior: translucent 确保空白区域点击穿透到 Stack children
    // 空状态 + idle 时：不创建手势识别器，让 tap 穿透到 EmptyState 按钮
    final gestureActive = !(widget.emptyStatePresent && isIdle);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: gestureActive ? _handleTap : null,
      onDoubleTap: gestureActive ? _handleDoubleTap : null,
      child: IgnorePointer(
        ignoring: widget.emptyStatePresent && !isIdle,
        child: MouseRegion(
          opaque: false,
          hitTestBehavior: HitTestBehavior.translucent,
          onHover: (_) => _onMouseMove(),
          onEnter: (_) {
            _hovering = true;
            _show();
          },
          onExit: (_) {
            _hovering = false;
            if (!isIdle) _scheduleHide();
          },
          child: IgnorePointer(
            ignoring: !_visible,
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // ControlBar 固定在底部 — 跟随淡入淡出
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: _opacity,
                      child: ControlBar(
                        engine: widget.engine,
                        isFullscreen: widget.isFullscreen,
                        isIdle: isIdle,
                        onPrevious: widget.onPrevious,
                        onNext: widget.onNext,
                        onTogglePlaylist: widget.onTogglePlaylist,
                        onSettings: widget.onSettings,
                        onOpenFile: widget.onOpenFile,
                        onToggleFullscreen: widget.onToggleFullscreen,
                        onTogglePlayMode: widget.onTogglePlayMode,
                        playModeIcon: widget.playModeIcon,
                        playModeActive: widget.playModeActive,
                        playModeLabel: widget.playModeLabel,
                        isVideo: widget.isVideo,
                        enableBlur: _visible,
                      ),
                    ),
                  ),
                  // 错误消息条：独立于控制栏淡入淡出
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 96,
                    child: ErrorBanner(
                      engine: widget.engine,
                      onOpenFile: widget.onOpenFile,
                      onRetry: widget.onOpenFile,
                    ),
                  ),
                  // OSD 浮动提示 — 替代 OverlayEntry
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: FadeTransition(
                          opacity: _osdAnim,
                          child: _OsdBubble(message: _osdMessage),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// OSD 气泡 — 毛玻璃背景的浮动提示文字
class _OsdBubble extends StatelessWidget {
  final String message;
  const _OsdBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: GlassContainer(
        tier: GlassTier.thick,
        respectResizeState: true,
        borderRadius: BorderRadius.circular(Tokens.radiusPopup),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          message,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontBody,
          ),
        ),
      ),
    );
  }
}
