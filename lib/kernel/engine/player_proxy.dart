import 'dart:async';

/// Abstract interface for player properties used by helper classes.
///
/// Defines the subset of mdk.Player API needed by VolumeController,
/// SubtitleConfigurator, and D3D11Configurator. Enables testing
/// with pure Dart fakes without FFI dependencies.
abstract class PlayerProxy {
  /// Set audio volume (0.0 - 1.0).
  set volume(double value);

  /// Set mute state.
  set mute(bool value);

  /// Set a player property by key-value pair.
  void setProperty(String key, String value);

  /// Get a player property value, or null if not set.
  String? getProperty(String key);
}

// ─── Callback event types (mdk-independent) ───

/// 播放状态枚举 — mdk.PlaybackState 的 Dart 镜像
///
/// 用于 FvpCallbackHandler 的状态映射，避免直接依赖 fvp/mdk.dart。
/// MdkPlayerProxy 将 mdk.PlaybackState 转换为此枚举后放入事件流。
enum MdkPlaybackState {
  stopped,
  playing,
  paused,
}

/// 媒体状态标志位 — mdk.MediaStatus 的 Dart 镜像
///
/// FvpCallbackHandler 通过 test() 方法检查 buffering/end 标志。
class MdkMediaStatus {
  final int _value;
  const MdkMediaStatus._(this._value);

  static const none = MdkMediaStatus._(0);
  static const buffering = MdkMediaStatus._(1);
  static const end = MdkMediaStatus._(8); // mdk.MediaStatus.end = 8

  /// 检查是否包含指定标志位
  bool test(MdkMediaStatus flag) => (_value & flag._value) != 0;

  /// 从 mdk.MediaStatus 创建（MdkPlayerProxy 使用）
  factory MdkMediaStatus.fromMdk(dynamic mdkStatus) {
    // mdk.MediaStatus 有 buffering/end 等属性，通过 .test() 检查
    // 这里通过位标志映射，保持与 mdk 的兼容性
    int value = 0;
    try {
      // mdk.MediaStatus.test(flag) 返回 bool
      // mdk.MediaStatus.buffering 的内部值
      if (mdkStatus.toString().contains('buffering')) value |= 1;
      if (mdkStatus.toString().contains('end')) value |= 8;
    } on Exception catch (_) {
      // 解析失败时返回 none
    }
    return MdkMediaStatus._(value);
  }

  /// 从原始 int 值创建（FakeMdkPlayer 使用）
  factory MdkMediaStatus.fromValue(int value) = MdkMediaStatus._;
}

/// 状态变化事件包装 — 替代 mdk.StateChangedEvent
class MdkStateChangedEvent {
  final MdkPlaybackState newValue;
  const MdkStateChangedEvent(this.newValue);
}

/// 媒体状态事件包装 — 替代 mdk.MediaStatusEvent
class MdkMediaStatusEvent {
  final MdkMediaStatus newValue;
  const MdkMediaStatusEvent(this.newValue);
}

/// Extended player interface covering the full mdk.Player API surface
/// needed by FvpEngine, MediaOpener, TrackManager, and engine helpers.
///
/// Extends [PlayerProxy] with media lifecycle, track control, playback
/// state, and event streams. Enables dependency injection of a fake player
/// in tests, eliminating the mdk.dll FFI dependency in headless CI.
///
/// Design rationale:
///   - [PlayerProxy] remains minimal for VolumeController/SubtitleConfigurator/D3D11Configurator
///   - [MdkPlayerLike] adds the full surface needed by engine core classes
///   - Production code uses [MdkPlayerProxy] wrapping real mdk.Player
///   - Tests use a pure Dart fake with no FFI imports
abstract class MdkPlayerLike implements PlayerProxy {
  // ─── Media lifecycle ───

  /// Set the media source path or URL.
  set media(String path);

  /// Prepare the media for playback. Returns >= 0 on success, < 0 on failure.
  Future<int> prepare();

  /// Get media metadata (duration, video/audio/subtitle tracks).
  ///
  /// The returned object must expose: duration, video (list with .first.codec),
  /// audio (list with .codec, .index, .metadata), subtitle (list with .index, .metadata).
  /// In production this is mdk.MediaInfo; in tests, a fake implementation.
  dynamic get mediaInfo;

  /// Create/update the video texture. Returns >= 0 on success.
  Future<int> updateTexture();

  /// Texture ID notifier — updated after updateTexture() succeeds.
  /// Must expose `.value` (int?) for reading the texture ID.
  dynamic get textureId;

  // ─── Track control ───

  /// Set active audio track indices.
  set activeAudioTracks(List<int> tracks);

  /// Get active audio track indices.
  List<int> get activeAudioTracks;

  /// Set active subtitle track indices (empty list to disable).
  set activeSubtitleTracks(List<int> tracks);

  /// Get active subtitle track indices.
  List<int> get activeSubtitleTracks;

  // ─── Playback state ───

  /// Set playback state (MdkPlaybackState in Dart, mdk.PlaybackState in production).
  set state(dynamic value);

  /// Get current playback state.
  dynamic get state;

  /// Start playback.
  void start();

  /// Stop playback.
  void stop();

  /// Get current playback position in milliseconds.
  int get position;

  /// Get buffered position in milliseconds (for streaming media).
  int buffered();

  /// Seek to [position] in milliseconds.
  /// Optional [callback] fires with true on success.
  Future<void> seek({required int position, void Function(bool)? callback});

  /// Set playback rate (1.0 = normal speed).
  set playbackRate(double rate);

  // ─── Buffer configuration ───

  /// Set buffer range for streaming media.
  void setBufferRange({required int min, required int max, required bool drop});

  /// Set AB loop range. Pass -1 for [to] to clear.
  void setRange({required int from, int to});

  // ─── Video properties ───

  /// Set video effect (brightness/contrast/hue/saturation).
  /// [effect] is the mdk.VideoEffect enum value; [values] is a single-element list.
  void setVideoEffect(Object? effect, List<double> values);

  /// Set video aspect ratio (e.g. 16/9 = 1.778).
  void setAspectRatio(double ratio);

  /// Rotate video by [degree] (must be 0, 90, 180, or 270).
  void rotate(int degree);

  // ─── Event streams ───

  /// State change events — emits [MdkStateChangedEvent] in Dart.
  /// MdkPlayerProxy maps from mdk.StateChangedEvent.
  Stream<dynamic> get onStateChanged;

  /// Media status events — emits [MdkMediaStatusEvent] in Dart.
  /// MdkPlayerProxy maps from mdk.MediaStatusEvent.
  Stream<dynamic> get onMediaStatus;

  // ─── Lifecycle ───

  /// Release all player resources.
  void dispose();
}
