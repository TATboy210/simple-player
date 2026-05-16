import 'package:flutter/foundation.dart';

import '../models/media_error_type.dart';
import '../models/media_state.dart';
import '../models/media_info.dart';
import '../models/video_effect_type.dart';

/// 媒体引擎抽象接口
///
/// 所有播放器后端（fvp/MDK、libmpv、video_player）必须实现此接口。
/// UI 层只依赖此接口，不直接接触底层引擎。
///
/// 设计原则:
///   - 10 个 ValueNotifier 暴露状态（与 Flutter 响应式对齐）
///   - 方法命名遵循 CQS: 命令式方法 void，查询式方法返回值
///   - 所有方法必须 _disposed 检查（Guard Clause 模式）
///   - 参数在入口处 clamp（防御式编程）
abstract class MediaEngine {
  // ─── 状态暴露 (ValueNotifier) ───

  /// 纹理 ID（用于 Texture widget），null 表示尚未就绪
  ValueNotifier<int?> get textureId;

  /// 播放器状态
  ValueNotifier<MediaState> get state;

  /// 当前播放位置（毫秒）
  ValueNotifier<int> get position;

  /// 媒体总时长（毫秒），未知时为 0
  ValueNotifier<int> get duration;

  /// 音量 0.0 - 1.0
  ValueNotifier<double> get volume;

  /// 是否静音
  ValueNotifier<bool> get isMuted;

  /// 是否正在缓冲
  ValueNotifier<bool> get isBuffering;

  /// 当前外挂字幕文本（无字幕时为空串）
  ValueNotifier<String> get subtitleText;

  /// 已缓冲量（毫秒）
  ValueNotifier<int> get buffered;

  /// 视频宽高比（width/height，含 PAR 修正），未知时为 16/9
  ValueNotifier<double> get aspectRatio;

  /// 错误消息（null = 无错误）
  ValueNotifier<String?> get errorMessage;

  /// 错误类型（UI 层根据类型选择操作按钮）
  MediaErrorType get errorType;

  /// 播放速度（0.25 - 4.0），默认 1.0
  ValueNotifier<double> get playbackSpeed;

  // ─── 媒体信息（open 后可用） ───

  /// 当前媒体信息
  MediaInfo get mediaInfo;

  // ─── 播放控制 ───

  /// 打开媒体文件（本地路径或 URL）
  ///
  /// 调用后 state 变为 loading → idle（成功）或 error（失败）。
  /// 不会自动播放，需显式调用 play()。
  Future<void> open(String path);

  /// 开始播放
  void play();

  /// 暂停
  void pause();

  /// 停止（重置位置到 0）
  void stop();

  /// 跳转到指定位置（毫秒）
  ///
  /// 实现方应自动 clamp(0, duration)。
  Future<void> seekTo(int milliseconds);

  /// 设置音量（0.0 - 1.0）
  void setVolume(double value);

  /// 设置静音
  void setMute(bool mute);

  /// 切换播放 / 暂停
  void togglePlayPause();

  /// 快进 N 秒（默认 10 秒）
  void skipForward([int seconds = 10]) {
    seekTo((position.value + seconds * 1000).clamp(0, duration.value));
  }

  /// 快退 N 秒（默认 10 秒）
  void skipBack([int seconds = 10]) {
    seekTo((position.value - seconds * 1000).clamp(0, duration.value));
  }

  /// 设置播放速度（0.25 - 4.0）
  void setPlaybackRate(double rate);

  /// AB 循环：设置范围 [fromMs, toMs]，传 -1 清除
  void setRange({required int from, int to = -1});

  // ─── 音轨 ───

  /// 获取可用音轨列表
  List<AudioTrackInfo> getAudioTracks();

  /// 切换到指定音轨索引
  void switchAudioTrack(int trackIndex);

  /// 获取当前激活的音轨索引列表
  List<int> get activeAudioTracks;

  // ─── 字幕 ───

  /// 获取可用字幕轨道列表
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道，传 -1 关闭字幕
  void switchSubtitleTrack(int trackIndex);

  /// 切换字幕开关
  void toggleSubtitle();

  // ─── 外挂字幕 ───

  /// 加载外挂字幕文件（.srt/.ass/.ssa/.vtt 路径）
  void setExternalSubtitle(String path);

  // ─── 字幕时间偏移 ───

  /// 设置字幕延迟（毫秒），正值延迟字幕，负值提前字幕
  void setSubtitleDelay(int milliseconds);

  /// 当前字幕延迟（毫秒）
  int get subtitleDelay;

  // ─── 均衡器 ───

  /// 设置均衡器（FFmpeg af 滤镜字符串）
  void setEqualizer(String afFilter);

  // ─── 视频处理 ───

  /// 设置视频效果（亮度/对比度/饱和度/色调）
  /// value 范围 [-1.0, 1.0]，默认 0.0
  void setVideoEffect(VideoEffectType effect, double value);

  /// 旋转视频（0/90/180/270 度，逆时针）
  void rotate(int degree);

  /// 设置宽高比
  /// 使用 AspectRatioMode.mdkValue 或自定义浮点值
  void setAspectRatio(double ratio);

  /// 启用/禁用去隔行（仅软件解码器生效）
  void setDeinterlace(bool enable);

  // ─── 生命周期 ───

  /// 释放所有资源
  void dispose();
}
