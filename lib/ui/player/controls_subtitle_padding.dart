import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/tokens.dart';
import 'mpv_kit_player_port.dart';

/// 字幕安全区自驱同步 — 控制栏显示时字幕上移避让、隐藏时恢复。
///
/// 只负责"何时写、写什么"：基础 padding 缓存、空写守卫、build 期间延迟到
/// post-frame；生命周期判定由 [canWrite] 注入 (mounted && !deactivating)。
class SubtitlePaddingSync {
  SubtitlePaddingSync({
    required this.readVideo,
    required this.barVisible,
    required this.canWrite,
  });

  /// 读取当前视频端口 (端口可被 didUpdateWidget 替换，故用 getter)。
  final VideoControlsPort Function() readVideo;

  /// 控制栏可见性 — 决定是否叠加底部 inset。
  final ValueListenable<bool> barVisible;

  /// 本控件是否仍可安全写端口 (挡 dispose 后 / deactivate 窗口)。
  final bool Function() canWrite;

  /// 控制栏可见时为字幕预留的底部安全区。
  static const _barInset = EdgeInsets.only(
    bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
  );

  /// 控件创建后读取一次的基础 padding，避免 activate 重复叠加自身 inset。
  EdgeInsets? _basePadding;

  /// 最近一次应用到端口的值 — 相同则跳过 (显隐翻转高频触发的空写守卫)。
  EdgeInsets? _lastApplied;
  bool _scheduled = false;

  /// 视频端口更换：基础值与空写守卫一并失效 (新端口必须至少收到一次写入)。
  void resetForNewPort() {
    _basePadding = null;
    _lastApplied = null;
  }

  /// 仅复位空写守卫 — activate 视为新写入契约起点 (reparent 后端口可能全新)。
  void resetGuard() => _lastApplied = null;

  /// 请求一次同步。
  ///
  /// 空闲阶段立即写以保持 stream 事件即时性；build/update 通知期间延迟到
  /// frame 结束，避免触发 SubtitleView 内部 setState() during build。
  void schedule() {
    if (_scheduled || !canWrite()) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      sync();
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      sync();
    });
  }

  /// 立即写入当前应有的 padding。
  ///
  /// 不可取消的 post-frame callback 可能在控件失效后触发；对已 deactivate 的
  /// 端口写 padding 会触发 "deactivated widget's ancestor" 断言，故先过
  /// [canWrite] 与端口 isMounted 两道守卫。
  void sync() {
    final video = readVideo();
    if (!canWrite() || !video.isMounted) return;
    // 只在当前 source 首次同步时读基础值；之后复用缓存，保证重复
    // activate/reparent 不会把已加过的 inset 再当作基础值。
    final base = _basePadding ??= video.subtitlePadding;
    final padding = barVisible.value ? base + _barInset : base;
    if (padding == _lastApplied) return;
    _lastApplied = padding;
    video.setSubtitleViewPadding(padding);
  }
}
