import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';

class _HoverState {
  const _HoverState(this.hovering, this.x);
  static const empty = _HoverState(false, 0.0);
  final bool hovering;
  final double x;
}

/// 进度条 — 已播放/未播放两层圆角矩形。
/// 支持：拖拽 seek（节流+阈值）、悬停展开动画、Tooltip 淡入淡出、
/// 滚轮 seek、悬停 thumb 与禁用状态。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [position]/[duration]
/// ValueListenable + [onSeek] 回调,seek-hold 逻辑不变(只换 position 来源)。
class ProgressBar extends StatefulWidget {
  /// 当前位置(ms)— seek-hold 监听它到达目标容差。
  final ValueListenable<int> position;

  /// 总时长(ms)— <=0 视为禁用态。
  final ValueListenable<int> duration;

  /// seek 回调(ms)— 拖拽/点击/瞬时 seek 统一出口。
  final void Function(int ms) onSeek;

  /// Window resize signal — when true, skip internal bar rebuild to save CPU.
  final ValueListenable<bool>? resizing;

  /// 用户开始拖动进度条回调 — 通知 AutoHideController 冻结隐藏计时
  final VoidCallback? onSeekStart;

  /// 用户结束拖动进度条回调 — 通知 AutoHideController 重启隐藏计时
  final VoidCallback? onSeekEnd;

  const ProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.resizing,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar>
    with TickerProviderStateMixin {
  final _dragNotifier = ValueNotifier<double?>(null);
  final _hoverNotifier = ValueNotifier<_HoverState>(_HoverState.empty);
  double _barWidth = 0;
  bool _reducedMotion = false;
  double? _dragStartX;

  /// Tooltip 只关心位置、时长、悬停和拖拽，不关心窗口 resize。
  late _MergedListenable _barListenable;

  /// 条形绘制额外关心高度动画和 resize，用一个 builder 合并处理，
  /// 避免“高度 AnimatedBuilder → 内层 bar AnimatedBuilder”的嵌套重建。
  late _MergedListenable _barPaintListenable;
  Timer? _seekThrottle;
  // 修 C (事件驱动 v2): dragEnd 后监听 position 到达目标才清 drag, 替代 v1 固定
  // 300ms 定时器. 比 media_kit_control_bar 原生内部协调更贴近 — 不依赖固定
  // 延迟, 网络流/慢 seek 下不回跳. 加超时兜底防 seek 失败永久卡住.
  VoidCallback? _seekHoldListener;
  int? _seekTargetMs;
  Timer? _seekHoldTimer; // 超时兜底: position 未到达时强制清

  // Tooltip 淡入淡出动画
  late final AnimationController _tooltipFadeController;
  late final Animation<double> _tooltipOpacity;

  // 悬停展开动画（3dp → 5dp）
  late final AnimationController _expandController;
  late final Animation<double> _barHeightAnimation;

  double get _hoverX => _hoverNotifier.value.x;

  double get _effectiveFraction {
    final dur = widget.duration.value;
    if (dur <= 0) return 0;
    final drag = _dragNotifier.value;
    if (drag != null) return drag;
    return (widget.position.value / dur).clamp(0.0, 1.0);
  }

  int get _dragPositionMs =>
      ((_dragNotifier.value ?? 0) * widget.duration.value).round();

  bool get _disabled => widget.duration.value <= 0;

  @override
  void initState() {
    super.initState();
    _barListenable = _buildBarListenable();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: Tokens.progressExpandDurationMs),
      vsync: this,
    );
    _barHeightAnimation =
        Tween<double>(
          begin: Tokens.progressBarThickness,
          end: Tokens.progressBarThicknessDrag,
        ).animate(
          CurvedAnimation(parent: _expandController, curve: Curves.easeOut),
        );
    _tooltipFadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _tooltipOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tooltipFadeController, curve: Curves.easeOut),
    );
    _barPaintListenable = _buildBarPaintListenable();
  }

  _MergedListenable _buildBarListenable() => _MergedListenable([
    widget.position,
    widget.duration,
    _dragNotifier,
    _hoverNotifier,
  ]);

  /// 合并条形绘制的所有高频状态，避免高度动画和条形状态各自重建一层。
  _MergedListenable _buildBarPaintListenable() {
    final listenables = <Listenable>[_barListenable, _barHeightAnimation];
    final resizing = widget.resizing;
    if (resizing != null) listenables.add(resizing);
    return _MergedListenable(listenables);
  }

  /// Replaces merged listeners as one owned unit, avoiding old-source leaks
  /// when a retained [ProgressBar] receives a replacement PlayerPort.
  void _replaceBarListenables() {
    _barPaintListenable.dispose();
    _barListenable.dispose();
    _barListenable = _buildBarListenable();
    _barPaintListenable = _buildBarPaintListenable();
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.duration != widget.duration ||
        oldWidget.resizing != widget.resizing) {
      _replaceBarListenables();
      if (oldWidget.position != widget.position && _seekHoldListener != null) {
        final target = _seekTargetMs;
        _cancelSeekHoldListeners(position: oldWidget.position);
        if (target != null) _beginSeekHold(target);
      }
    }
  }

  @override
  void dispose() {
    _seekThrottle?.cancel();
    _cancelSeekHoldListeners();
    _barPaintListenable.dispose();
    _barListenable.dispose();
    _dragNotifier.dispose();
    _hoverNotifier.dispose();
    _expandController.dispose();
    _tooltipFadeController.dispose();
    super.dispose();
  }

  void _updateTooltipVisibility() {
    if (_reducedMotion) return;
    final show = _hoverNotifier.value.hovering || _dragNotifier.value != null;
    if (show) {
      _expandController.forward();
      _tooltipFadeController.forward();
    } else {
      _expandController.reverse();
      _tooltipFadeController.reverse();
    }
  }

  /// 修 C (事件驱动 v2): dragEnd 后启动 seek hold — 监听 [widget.position]
  /// 到达 [targetMs] 容差内才清 [_dragNotifier], 遮住旧 stream 回拨防回跳.
  /// 加超时兜底: seek 失败/极慢时强制清, 避免进度条永久卡在 drag 位置.
  void _beginSeekHold(int targetMs) {
    _cancelSeekHoldListeners();
    _seekTargetMs = targetMs;
    // 局部函数声明 (非闭包变量赋值, 避免 prefer_function_declarations_over_variables);
    // 复用函数名消除 addListener/call 的 `!`; 内 _seekTargetMs local 捕获消除 `!`
    void listener() {
      if (!mounted) return;
      final target = _seekTargetMs;
      if (target == null) return;
      final pos = widget.position.value;
      if ((pos - target).abs() <= Tokens.progressSeekArriveToleranceMs) {
        _finishSeekHold();
      }
    }

    _seekHoldListener = listener;
    // 先建超时 timer, 再 addListener + 立即检查 — 若立即检查触发 _finishSeekHold,
    // _cancelSeekHoldListeners 会 cancel 此 timer; 顺序反了 (timer 在 call 之后建)
    // 会留下无人取消的 pending timer, 触发 flutter_test 的 !timersPending 断言.
    _seekHoldTimer = Timer(
      const Duration(milliseconds: Tokens.progressSeekHoldTimeoutMs),
      _finishSeekHold,
    );
    widget.position.addListener(listener);
    // 立即检查一次: FakeEngine/同步 seek 可能已让 position 到达目标,
    // addListener 只对未来变化触发, 不立即检查会卡到超时 (测试/同步路径).
    listener.call();
  }

  /// 清理 seek hold 的监听 + 超时 timer, 不动 [_dragNotifier].
  /// 用于 dragStart (新 drag 覆盖前) / dispose 取消未完成 hold.
  void _cancelSeekHoldListeners({ValueListenable<int>? position}) {
    _seekHoldTimer?.cancel();
    _seekHoldTimer = null;
    final listener = _seekHoldListener;
    if (listener != null) {
      // During source replacement, widget.position already points at the new
      // port; use the old source explicitly to detach the existing callback.
      (position ?? widget.position).removeListener(listener);
      _seekHoldListener = null;
    }
    _seekTargetMs = null;
  }

  /// seek hold 正常完成: position 已到达目标 (或超时兜底) — 清监听 + 清 drag.
  void _finishSeekHold() {
    if (!mounted) return;
    _cancelSeekHoldListeners();
    _dragNotifier.value = null;
    _updateTooltipVisibility();
  }

  @override
  Widget build(BuildContext context) {
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        _barWidth = barWidth;
        return MouseRegion(
          cursor: _disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) {
            if (_disabled) return;
            _hoverNotifier.value = _HoverState(true, _hoverX);
            _updateTooltipVisibility();
          },
          onExit: (_) {
            // 拖拽中不重置 hover，防止松手时 thumb 闪跳到 0.0
            if (_dragNotifier.value != null) return;
            _hoverNotifier.value = _HoverState.empty;
            _updateTooltipVisibility();
          },
          onHover: (details) {
            if (_disabled) return;
            // 修 D: 直接更新 — hover 事件系统已节流,无需 postFrame 防抖
            // (原 postFrame+_hoverScheduled 引入一帧延迟+漏更新,致 tooltip 不跟手)
            _hoverNotifier.value = _HoverState(
              true,
              (details.localPosition.dx / barWidth).clamp(0.0, 1.0),
            );
          },
          child: AnimatedBuilder(
            // Semantics is outside the painter, so it must listen explicitly
            // to expose stream-driven progress instead of retaining build-time 0%.
            animation: _barListenable,
            builder: (context, child) => Semantics(
              label: AppLocalizations.of(context).progressBar,
              value: '${(_effectiveFraction * 100).round()}%',
              slider: true,
              child: child,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 修 A: 回调始终非 null,体内判断 duration — 避免 _disabled 顶层 build 快照陈旧
              // (duration stream 到达后只触发子 AnimatedBuilder,不触发顶层 build,致回调永久 null)
              onHorizontalDragStart: (details) {
                if (widget.duration.value <= 0) return;
                // 新 drag 开始 — 取消上次 dragEnd 未完成的 seek hold,
                // 防旧 listener 在新 drag 期间触发 _finishSeekHold 清掉新 drag 状态.
                _cancelSeekHoldListeners();
                // 通知 auto-hide 冻结隐藏计时(seek 期间控件不消失)
                widget.onSeekStart?.call();
                _dragStartX = details.localPosition.dx;
                _updateTooltipVisibility();
              },
              onHorizontalDragUpdate: (details) {
                if (widget.duration.value <= 0) return;
                final dx = details.localPosition.dx;
                // 拖拽阈值：防止误触
                if (_dragNotifier.value == null) {
                  final start = _dragStartX;
                  if (start != null &&
                      (dx - start).abs() < Tokens.progressDragThreshold) {
                    return;
                  }
                  _dragStartX = null;
                }
                _dragNotifier.value = (dx / barWidth).clamp(0.0, 1.0);
                // 修 B: leading throttle — timer 未活跃才 seek+启动,活跃期跳过
                // (原 cancel+重建 debounce 致拖动中永不 seek,松手才跳)
                if (!(_seekThrottle?.isActive ?? false)) {
                  widget.onSeek(_dragPositionMs);
                  _seekThrottle = Timer(
                    const Duration(milliseconds: Tokens.progressSeekThrottleMs),
                    () {},
                  );
                }
              },
              onHorizontalDragEnd: (_) {
                _dragStartX = null;
                _seekThrottle?.cancel();
                // 配对 onSeekStart — 重启隐藏计时(即使未真正拖动也保持 start/end 配对,
                // 避免 onSeekStart cancel 了 timer 却无 onSeekEnd 重启导致控件永显)
                if (widget.duration.value > 0) {
                  widget.onSeekEnd?.call();
                }
                if (_dragNotifier.value == null) return;
                if (widget.duration.value <= 0) {
                  _dragNotifier.value = null;
                  _updateTooltipVisibility();
                  return;
                }
                widget.onSeek(_dragPositionMs);
                // 修 C (事件驱动 v2): 不立即清 drag — 监听 position 到达目标容差内
                // 才清, 遮住旧 stream 回拨防回跳. 比 v1 固定 300ms 更贴近原生内部
                // 协调, 网络流/慢 seek 下不回跳. 超时兜底防 seek 失败永久卡住.
                _beginSeekHold(_dragPositionMs);
                // 恢复悬停状态（鼠标仍在 bar 上）
                _hoverNotifier.value = _HoverState(true, _hoverX);
                _updateTooltipVisibility();
              },
              onTapDown: (details) {
                if (widget.duration.value <= 0) return;
                // 瞬时 seek — 配对 start+end(等同 show + scheduleHide:
                // 闪现控件,3s 后隐藏)
                widget.onSeekStart?.call();
                final fraction = (details.localPosition.dx / barWidth).clamp(
                  0.0,
                  1.0,
                );
                final ms = (fraction * widget.duration.value).round();
                widget.onSeek(ms);
                widget.onSeekEnd?.call();
              },
              child: SizedBox(
                height: Tokens.progressBarHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 合并高度动画与条形状态监听；避免高度 builder
                    // 每帧重新创建一个内层 AnimatedBuilder。
                    _buildBarLayers(),
                    // 悬停/拖拽时间提示
                    // tooltip 指向 _barListenable(已含 _dragNotifier+_hoverNotifier),
                    // 拖动时跟随手指更新文字/位置(VLC TimeTooltip / mpv tooltipF 本地计算)
                    AnimatedBuilder(
                      animation: _barListenable,
                      builder: (_, _) {
                        final drag = _dragNotifier.value;
                        final hover = _hoverNotifier.value;
                        final isDragging = drag != null;
                        final fraction = isDragging
                            ? drag
                            : hover.hovering
                            ? hover.x
                            : null;
                        if (fraction == null || _disabled) {
                          return const SizedBox.shrink();
                        }
                        return _buildTooltip(
                          fraction: fraction,
                          text: formatMs(
                            (fraction * widget.duration.value).round(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 缓存上一帧的 CustomPaint — resize 期间直接复用，避免每帧重建 painter（CB-06 wiring 修复后此缓存才生效）
  Widget? _cachedCustomPaint;

  Widget _buildBarLayers() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _barPaintListenable,
        builder: (_, _) {
          final resizing = widget.resizing;
          // 缓存只用于加速 resize，不能在缓存尚未建立时用空组件替代进度条。
          // 首次进入 resize 直接绘制当前状态，后续帧再复用已缓存的 CustomPaint。
          final cached = _cachedCustomPaint;
          if (resizing != null && resizing.value && cached != null) {
            return cached;
          }
          final playedFrac = _effectiveFraction;
          final child = CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(
              playedFraction: playedFrac,
              dragging: _dragNotifier.value != null,
              barHeight: _barHeightAnimation.value,
              hoverFraction: _hoverNotifier.value.hovering ? _hoverX : null,
              disabled: _disabled,
            ),
          );
          _cachedCustomPaint = child;
          return child;
        },
      ),
    );
  }

  Widget _buildTooltip({required double fraction, required String text}) {
    const tooltipWidth = 52.0;
    const tooltipOffset = 20.0;
    final halfW = tooltipWidth / 2 + Tokens.spXs;
    final left = (fraction * _barWidth - tooltipWidth / 2)
        .clamp(halfW, _barWidth - halfW)
        .toDouble();
    return Positioned(
      bottom: tooltipOffset,
      left: left,
      child: FadeTransition(
        opacity: _tooltipOpacity,
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spXs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Tokens.bgGlass,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            border: Border.all(color: Tokens.borderHighlight, width: 0.5),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontOverline,
              fontFeatures: [Tokens.tabularFigures],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns the forwarding registrations created for a group of listenables.
///
/// [Listenable.merge] has no disposal API, so a retained widget state must keep
/// explicit callbacks and remove them when its PlayerPort sources are replaced.
class _MergedListenable extends ChangeNotifier {
  _MergedListenable(List<Listenable> sources) : _sources = List.of(sources) {
    for (final source in _sources) {
      source.addListener(notifyListeners);
    }
  }

  final List<Listenable> _sources;

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

class _BarPainter extends CustomPainter {
  final double playedFraction;
  final bool dragging;
  final double barHeight;
  final double? hoverFraction;
  final bool disabled;

  _BarPainter({
    required this.playedFraction,
    required this.dragging,
    required this.barHeight,
    this.hoverFraction,
    required this.disabled,
  });

  static final _bgPaint = Paint()..color = Tokens.bgHover;
  static final _bgDisabledPaint = Paint()
    ..color = Tokens.bgHover.withValues(alpha: Tokens.progressDisabledBgAlpha);
  static final _playedPaint = Paint()..color = Tokens.progressPlayed;
  static final _playedDisabledPaint = Paint()
    ..color = Tokens.progressPlayed.withValues(
      alpha: Tokens.progressDisabledPlayedAlpha,
    );
  static final _thumbPaint = Paint()..color = Tokens.progressThumb;

  static const _thumbWidth = 18.0;
  static const _thumbHeight = 12.0;
  static const _thumbRadius = Radius.circular(2.0);

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - barHeight) / 2;

    final bg = disabled ? _bgDisabledPaint : _bgPaint;
    final played = disabled ? _playedDisabledPaint : _playedPaint;

    const radius = Radius.circular(Tokens.progressBarRadius);

    // 背景层（圆角）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, barHeight),
        radius,
      ),
      bg,
    );
    // 已播放层（圆角）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width * playedFraction, barHeight),
        radius,
      ),
      played,
    );

    // thumb 始终显示在播放进度位置（不跟随鼠标）
    if (!disabled) {
      final cx = size.width * playedFraction;
      final cy = top + barHeight / 2;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: _thumbWidth,
        height: _thumbHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, _thumbRadius),
        _thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.playedFraction != playedFraction ||
      old.dragging != dragging ||
      old.barHeight != barHeight ||
      old.hoverFraction != hoverFraction ||
      old.disabled != disabled;
}
