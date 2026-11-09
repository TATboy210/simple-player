// ignore_for_file: invalid_use_of_visible_for_testing_member

/// mpv_kit (libmpv 0.41 FFI) 后端的 [MediaEngine] 实现 — 唯一后端.
///
/// mpv_kit backend: [Player] property observers (`MpvState`) and mpv events
/// bridged into the project's ValueNotifier contract. 实现拆在同库 part 文件:
/// - `mpv_kit_engine_state.dart`    状态底座 (字段/notifier/getter/守卫)
/// - `mpv_kit_engine_playback.dart` PlaybackControl + VolumeControl
/// - `mpv_kit_engine_tracks.dart`   轨道/字幕/视频效果/渲染器 facet
/// - `mpv_kit_engine_queue.dart`    QueueControl
/// - `mpv_kit_engine_bridge.dart`   mpv 状态/事件 → notifier 桥接
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io' show File, FileSystemException, Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mpv_kit_video/mpv_kit_video.dart';

import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import '../diagnostics/runtime_environment_report.dart';
import '../models/play_mode.dart';
import '../models/player_error.dart';
import 'media_engine.dart';
import 'media_state.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'mpv_kit_errors.dart';
import 'mpv_kit_tracks.dart';
import 'mpv_property_mapper.dart';
import 'open_failure_circuit_breaker.dart';
import 'open_result.dart';
import 'playlist_move_planner.dart';
import 'shuffle_policy.dart';
import 'video_effect_type.dart';
import 'volume_resync_gate.dart';

part 'mpv_kit_engine_bridge.dart';
part 'mpv_kit_engine_playback.dart';
part 'mpv_kit_engine_queue.dart';
part 'mpv_kit_engine_state.dart';
part 'mpv_kit_engine_tracks.dart';

/// mpv_kit 后端的 [MediaEngine] 实现.
///
/// 与旧后端 (media_kit) 的语义差异 (均为直接取 mpv 原生信号, 而非包内推导):
/// - EOF: `end-file` (reason eof) 事件驱动完成态 (keep-open=no 下
///   eof-reached 不会稳定为真).
/// - 装载成功: `file-loaded` 事件 (熔断复位 + file-scoped 属性重放).
/// - 路径直传 mpv, 无 URI 编解码层 (`#`/`%` 文件名天然安全).
class MpvKitEngine extends _MpvKitState
    with _MpvKitPlayback, _MpvKitQueueApi, _MpvKitTracks, _MpvKitEffects {
  /// 构造引擎并创建 mpv 核心 (同步; libmpv 由 mpv_kit_libs 打包).
  ///
  /// [playerOptions] 覆盖 [defaultOptions] (测试传 `vo=null`/`ao=null`).
  /// 视频输出须另行 `await attachVideo()` — 渲染上下文创建是异步的.
  ///
  /// [fileExists] 仅供测试注入失败条目存在性探测 (默认异步 `File.exists`).
  MpvKitEngine({
    Map<String, String> playerOptions = const {},
    @visibleForTesting Future<bool> Function(String path)? fileExists,
  }) : super(
         Player(options: {...defaultOptions, ...playerOptions}),
         fileExists ?? ((path) => File(path).exists()),
       ) {
    _subscribe();
  }

  /// 全局 mpv 选项 — 在 `mpv_initialize` 前生效.
  ///
  /// 内存治理 (v0.0.9) 的覆写值 (自旧后端沿用); 字幕两项服务于
  /// "libass 画进纹理 + sub-margin-y 避让控制栏" (见 `setSubtitleBottomInset`).
  static const Map<String, String> defaultOptions = <String, String>{
    // 本地文件无网络抖动可抗, 磁盘 demuxer 缓存只增 IO 与页缓存.
    'cache-on-disk': 'no',
    // 后向缓冲 8MB — 本地回退 seek 直接重读盘, 大后向缓冲白占 RSS.
    'demuxer-max-back-bytes': '8388608',
    // 播完即卸载解码链 (v0.0.9 泄漏治理: 停播后 RSS 回落).
    'keep-open': 'no',
    // 硬解白名单全覆盖 — 不在名单的格式会静默回退软解, 4K60 必卡.
    'hwdec-codecs': 'all',
    'hwdec': 'auto-safe',
    // 注: 旧后端的 `demuxer-max-secs=10` 已删 — mpv 0.41 无此选项
    // (旧 setProperty 一直静默失败、从未生效); 前向缓冲由 bytes 上限约束.
    // ASS 普通对白也服从 sub-margin-y (\pos 定位的特效字幕不受影响).
    'sub-ass-force-margins': 'yes',
    'sub-margin-y': '$_baseSubMarginY',
  };

  /// mpv `sub-margin-y` 默认值 (缩放像素, 以 720p 窗口高度为基准).
  static const int _baseSubMarginY = 22;

  /// sub-margin-y 缩放像素的参考窗口高度 (`sub-scale-by-window=yes`).
  static const double _subScaleReferenceHeight = 720;

  /// volume 回声识别窗口大小 (在途下发值条数上限).
  static const int _echoWindow = 8;

  /// volume 回声判等容差 (mpv 0~100 刻度) — 远小于任何可感知音量步进.
  static const double _echoTolerance = 0.01;

  /// mpv_kit [Player] — UI 端口 (进度条直连流) 与诊断使用.
  Player get player => _player;

  /// 视频输出控制器; [attachVideo] 完成前为 null.
  MpvVideoController? get videoController => _video;

  /// 创建视频渲染上下文 (Vulkan 零拷贝, 失败回退软件渲染) 并发布 textureId.
  ///
  /// side effect: 向 mpv 注册 render context; 失败抛 PlatformException,
  /// 由 PlayerServices 初始化链统一处理.
  Future<void> attachVideo() async {
    if (_disposed || _video != null) return;
    final video = await MpvVideoController.create(_player);
    if (_disposed) {
      await video.dispose();
      return;
    }
    _video = video;
    _textureId.value = video.textureId;
    _log('mpv_kit 视频输出: backend=${video.backend.name} (${video.reason})');
    // 跨机器排障: release 日志为 NullSink, 渲染路径落盘到 environment.txt.
    RuntimeEnvironmentReport.I
      ..record('render.backend', video.backend.name)
      ..record('render.reason', video.reason);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_trackTableChanged.close());
    for (final s in _subscriptions) {
      // 单个订阅取消失败不得变成未处理的异步异常, 也不得阻断其余订阅的取消.
      unawaited(
        s.cancel().catchError((Object error) {
          _log('订阅取消失败 (忽略): $error');
        }),
      );
    }
    _subscriptions.clear();
    for (final n in <ChangeNotifier>[
      _textureId,
      _state,
      _position,
      _duration,
      _volume,
      _isMuted,
      _lastError,
      _playbackSpeed,
      _queuePaths,
      _queueIndex,
      _queueRevision,
      _playMode,
    ]) {
      n.dispose();
    }
    // Player.dispose 先跑 dispose hook (视频控制器先于 mpv 核心释放).
    unawaited(_player.dispose());
  }
}
