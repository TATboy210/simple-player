/// Services 层播放控制模块 — 单文件播放器门面
///
/// 本文件实现 [PlaybackController] 作为单文件播放器运行时能力的统一入口，
/// UI 层只与本类交互。
///
/// 架构位置：PlayerViewModel → **PlaybackController** → MediaEngine
/// 设计模式：Facade（门面模式）— 简化 UI 层对播放能力的调用路径
///
/// v1.8 重写：移除播放队列/历史/断点/播放模式，回归单文件播放。
/// - 打开：[openAndPlay] 内联路径校验 + engine.open + OpenResult 分发
/// - 播完：engine completed 不主动处理（播完停止，符合产品决策）
/// - 状态：音量/静音由引擎默认值管理（用户设置已移除）
/// - 当前媒体：[currentPath] / [currentFileName] ValueNotifier 驱动 UI
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';
import '../engine/engine_state.dart';
import '../utils/debug_probe.dart';
import '../utils/path_utils.dart';
import 'path_validator.dart';
import 'subtitle_service.dart';
import 'track_preference_service.dart';

final _log = KernelLogger.I;

/// 播放控制器 — 单文件播放器运行时能力的统一门面入口
///
/// 职责划分：
/// - 打开并播放：[openAndPlay]（路径校验 → engine.open → OpenResult 分发）
/// - 停止卸载：[stopCurrentMedia]
/// - 播放/暂停：pause / play / isPlaying 薄委托（无打开流程交互）
///
/// 生命周期：使用 → dispose()（无 init 副作用，用户设置已移除）
class PlaybackController {
  PlaybackController({
    required this.engine,
    void Function(PlayerError error)? onError,
    SubtitleService? subtitleService,
    TrackPreferenceService? trackPreferenceService,
  }) : _onError = onError,
       _subtitleService = subtitleService,
       _trackPreferenceService = trackPreferenceService;

  /// 视频渲染引擎实例.
  ///
  /// Media engine instance.
  final MediaEngine engine;

  /// 错误回调 — 捕获异常时调用（null 表示忽略错误）
  final void Function(PlayerError error)? _onError;

  /// 字幕服务 — 可选依赖，null 表示无外挂字幕支持
  final SubtitleService? _subtitleService;

  /// 轨道偏好服务 — 可选依赖，null 表示不持久化轨道偏好
  final TrackPreferenceService? _trackPreferenceService;

  /// 调试探针 — 记录播放控制操作的耗时和事件（编译时开关 kDebugMode）.
  ///
  /// Debug probe — records timing and events (compile-time kDebugMode gate).
  final DebugProbe probe = DebugProbeRegistry.register('playback');

  /// 当前播放文件名（仅文件名，不含路径）— UI 层显示标题栏文件名.
  ///
  /// Current playback file name (basename only) — displayed in title bar.
  final ValueNotifier<String> currentFileName = ValueNotifier('');

  /// 当前播放文件绝对路径（null 表示无媒体加载）.
  ///
  /// 替代原 `playlist.current` 的「当前媒体引用」职责；
  /// 队列/历史/断点/播放模式职责已在 v1.8 移除。
  final ValueNotifier<String?> currentPath = ValueNotifier<String?>(null);

  /// 最近一次路径校验错误（null 表示无错误）— UI 层显示用.
  final ValueNotifier<String?> validationError = ValueNotifier<String?>(null);

  /// 错误回调（子模块通过 `_controller.onError?.call(error)` 调用）.
  ///
  /// Error callback invoked by sub-modules.
  void Function(PlayerError error)? get onError => _onError;

  /// 获取字幕服务（可能为 null）.
  ///
  /// Returns the subtitle service, or null if not configured.
  SubtitleService? get subtitleService => _subtitleService;

  /// 获取轨道偏好服务（可能为 null）.
  ///
  /// Returns the track preference service, or null if not configured.
  TrackPreferenceService? get trackPreferenceService => _trackPreferenceService;

  /// 暂停播放 — 直接委托 [MediaEngine.pause]，不与打开流程交互.
  ///
  /// Pauses playback. Thin forwarder; does not touch the open flow.
  void pause() => engine.pause();

  /// 恢复播放 — 直接委托 [MediaEngine.play].
  ///
  /// Resumes playback. Thin forwarder to the engine.
  void play() => engine.play();

  /// 是否正在播放 — 从引擎 [MediaState] notifier 派生，非独立布尔标志.
  bool get isPlaying => engine.state.value == MediaState.playing;

  /// 切换播放与暂停状态。
  ///
  /// 状态合法性与不可切换状态的 no-op 行为由 [MediaEngine] 统一处理。
  void togglePlayPause() => engine.togglePlayPause();

  /// 将当前位置向后跳转 [ms] 毫秒。
  ///
  /// 位置边界由 [MediaEngine] clamp，默认快退 10 秒。
  void skipBack([int ms = 10000]) => engine.skipBack(ms);

  /// 将当前位置向前跳转 [ms] 毫秒。
  ///
  /// 位置边界由 [MediaEngine] clamp，默认快进 10 秒。
  void skipForward([int ms = 10000]) => engine.skipForward(ms);

  // ── 单文件播放 ──

  /// 打开并播放单个文件 — 完整打开流程（路径校验 → engine.open → 副作用提交）.
  ///
  /// 并发安全由引擎 [OpenResult] 契约表达：较新的打开请求使旧请求返回
  /// [OpenSuperseded]，本方法据此跳过旧请求的副作用（字幕检测 / 标题更新等），
  /// 无需自维护 generation 计数器。
  ///
  /// 返回 true 表示成功打开并开始播放；
  /// false 表示校验失败 / 打开错误 / 被更新请求淘汰。
  Future<bool> openAndPlay(String path) async {
    final validationMsg = PathValidator.validate(path);
    if (validationMsg != null) {
      validationError.value = validationMsg;
      onError?.call(FileError(FileErrorCode.pathTraversal, validationMsg));
      return false;
    }
    validationError.value = null;

    final result = await engine.open(path);
    switch (result) {
      case OpenSuccess():
        // 字幕检测不影响主播放链路，失败仅记录诊断信息。
        unawaited(
          subtitleService?.detectAndLoad(path).catchError((Object error) {
            _log.d('Subtitle detection failed: $error');
          }),
        );
        trackPreferenceService?.restoreAfterOpen(engine.mediaInfo);
        engine.play();
        currentFileName.value = PathUtils.basename(path);
        currentPath.value = path;
        return true;
      case OpenError(:final error):
        onError?.call(error);
        return false;
      case OpenSuperseded():
        // 旧请求被新请求淘汰，不提交任何属于旧请求的副作用。
        return false;
    }
  }

  /// 停止并卸载当前媒体。
  ///
  /// 只有引擎确认媒体已卸载时才清空活动标题与路径；停止失败会保留标题，
  /// 使 UI 与仍可恢复的底层媒体状态保持一致。
  Future<void> stopCurrentMedia() async {
    await engine.stop();
    if (engine.hasMedia) return;
    currentFileName.value = '';
    currentPath.value = null;
  }

  // ── 生命周期 ──

  /// 释放运行时资源和状态通知器。
  void dispose() {
    currentFileName.dispose();
    currentPath.dispose();
    validationError.dispose();
  }
}
