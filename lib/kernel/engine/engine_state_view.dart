import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/kernel/engine/models/media_info.dart';

/// 播放器只读状态视图 — UI 层监听用
///
/// 将所有响应式状态聚合为只读 getter，UI 层通过
/// [ValueListenableBuilder] 监听变化，不直接修改状态。
///
/// 与 [PlaybackControl] 分离：此接口仅暴露状态，不包含控制方法。
/// 实现者是具体的引擎类（MediaKitEngine），消费者通过此接口
/// 以只读方式访问播放状态。
///
/// requires: 无（所有 getter 幂等、无参数、永不 throw）
/// ensures: 返回值反映最近一次内部状态更新；disposed 后返回安全默认值
///   （state→idle, position/duration→0, isSeeking/isBuffering→false，见 D9）
/// modifies: 无（本接口所有成员均为纯读取，无副作用）
abstract class EngineStateView {
  /// 纹理 ID — 用于 Texture 渲染，null 表示尚未就绪
  ValueNotifier<int?> get textureId;

  /// 主播放状态 — 正交 6 值枚举（idle/opening/playing/paused/completed/error）
  ValueNotifier<MediaState> get state;

  /// 当前播放位置（毫秒）
  ValueNotifier<int> get position;

  /// 媒体总时长（毫秒）
  ValueNotifier<int> get duration;

  /// 音量（0.0 ~ 1.0）
  ValueNotifier<double> get volume;

  /// 是否静音
  ValueNotifier<bool> get isMuted;

  /// 是否正在缓冲 — transient 标志，独立于主状态枚举
  ValueNotifier<bool> get isBuffering;

  /// 是否正在 seek — transient 标志，独立于主状态枚举
  ValueNotifier<bool> get isSeeking;

  /// 当前字幕文本
  ValueNotifier<String> get subtitleText;

  /// 已缓冲位置（毫秒）
  ValueNotifier<int> get buffered;

  /// 视频宽高比
  ValueNotifier<double> get aspectRatio;

  /// 最近一次错误 — null 表示无错误
  ValueNotifier<PlayerError?> get lastError;

  /// 播放速度倍率
  ValueNotifier<double> get playbackSpeed;

  /// 媒体元信息（编解码、分辨率、轨道列表）
  MediaInfo get mediaInfo;

  /// 轨道表变更通知流 — 底层轨道表更新时发出事件（装载后首帧回流等）.
  ///
  /// Track-table change notification stream — emitted whenever the
  /// underlying track table updates (e.g. the first frame after a load).
  ///
  /// 时序契约 (K4-b): open resolve 即刻读 [mediaInfo] 是陈旧读 — 轨道流
  /// 尚未回流, 读到的是上一文件的表（首次开启为空表）. 需要就绪轨道表的
  /// 调用方（轨道偏好恢复）必须等待 open 之后本流的下一个事件再读.
  /// 广播流无缓冲: 订阅须先于事件建立.
  Stream<void> get trackTableChanged;

  /// 释放所有 ValueNotifier 资源
  void dispose();
}
