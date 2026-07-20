import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:simple_player_flutter/kernel/engine/player_proxy.dart';

/// 纯 Dart mdk.Player 测试替身 — 实现 [MdkPlayerLike] 接口
///
/// 不 import fvp/mdk.dart，不依赖 FFI/DLL，可在 headless CI 中运行。
/// 所有行为可通过字段配置，支持 call tracking 用于测试断言。
///
/// 使用方式:
/// ```dart
/// final fake = FakeMdkPlayer();
/// fake.prepareResult = 1; // 成功
/// fake.mediaInfoToReturn = FakeMdkMediaInfo(duration: 60000);
/// final engine = FvpEngine(playerFactory: () => fake);
/// ```
class FakeMdkPlayer implements MdkPlayerLike {
  // ─── Configurable behavior ───

  /// prepare() 返回值 — >=0 成功, <0 失败
  int prepareResult = 1;

  /// prepare() 延迟 — 模拟异步加载
  Duration prepareDelay = Duration.zero;

  /// updateTexture() 返回值 — >=0 成功, <0 失败
  int updateTextureResult = 1;

  /// 纹理 ID — updateTexture 成功后暴露
  int? textureIdValue;

  /// mediaInfo 返回值 — 可配置为 FakeMdkMediaInfo
  dynamic mediaInfoToReturn;

  /// seek 延迟 — 模拟异步 seek
  Duration seekDelay = Duration.zero;

  // ─── Call tracking ───

  String mediaPath = '';
  int prepareCallCount = 0;
  int updateTextureCallCount = 0;
  int seekCallCount = 0;
  int? lastSeekPosition;
  int setPropertyCallCount = 0;
  final Map<String, String> properties = {};
  final List<List<int>> activeAudioTracksHistory = [];
  final List<List<int>> activeSubtitleTracksHistory = [];

  // ─── Internal state ───

  dynamic _state;
  double _volume = 1.0;
  bool _mute = false;
  double _playbackRate = 1.0;
  int _position = 0;
  bool _disposed = false;

  /// 播放状态事件流控制器
  final _stateController = StreamController<dynamic>.broadcast();

  /// 媒体状态事件流控制器
  final _statusController = StreamController<dynamic>.broadcast();

  /// 纹理 ID notifier — 模拟 mdk.Player.textureId
  final textureIdNotifier = ValueNotifier<int?>(null);

  // ─── MdkPlayerLike: Media lifecycle ───

  @override
  set media(String path) {
    mediaPath = path;
  }

  @override
  Future<int> prepare() async {
    prepareCallCount++;
    if (prepareDelay != Duration.zero) {
      await Future<void>.delayed(prepareDelay);
    }
    return prepareResult;
  }

  @override
  dynamic get mediaInfo => mediaInfoToReturn;

  @override
  Future<int> updateTexture() async {
    updateTextureCallCount++;
    if (updateTextureResult >= 0) {
      textureIdNotifier.value = textureIdValue ?? 1;
    }
    return updateTextureResult;
  }

  @override
  dynamic get textureId => textureIdNotifier;

  // ─── MdkPlayerLike: Track control ───

  List<int> _activeAudioTracks = [];
  List<int> _activeSubtitleTracks = [];

  @override
  set activeAudioTracks(List<int> tracks) {
    _activeAudioTracks = List.from(tracks);
    activeAudioTracksHistory.add(List.from(tracks));
  }

  @override
  List<int> get activeAudioTracks => _activeAudioTracks;

  @override
  set activeSubtitleTracks(List<int> tracks) {
    _activeSubtitleTracks = List.from(tracks);
    activeSubtitleTracksHistory.add(List.from(tracks));
  }

  @override
  List<int> get activeSubtitleTracks => _activeSubtitleTracks;

  // ─── MdkPlayerLike: Playback state ───

  @override
  set state(dynamic value) => _state = value;

  @override
  dynamic get state => _state;

  @override
  void start() {
    // no-op in fake
  }

  @override
  void stop() {
    _position = 0;
  }

  @override
  int get position => _position;

  /// 供测试直接设置 position 值
  set positionForTest(int value) => _position = value;

  /// 可配置的 buffered 值 — 用于流媒体测试
  int bufferedValue = 0;

  @override
  int buffered() => bufferedValue;

  @override
  Future<void> seek({required int position, void Function(bool)? callback}) async {
    seekCallCount++;
    lastSeekPosition = position;
    if (seekDelay != Duration.zero) {
      await Future<void>.delayed(seekDelay);
    }
    _position = position;
    callback?.call(true);
  }

  @override
  set playbackRate(double rate) => _playbackRate = rate;

  // ─── MdkPlayerLike: PlayerProxy (volume/mute/property) ───

  @override
  set volume(double value) => _volume = value;

  @override
  set mute(bool value) => _mute = value;

  @override
  void setProperty(String key, String value) {
    setPropertyCallCount++;
    properties[key] = value;
  }

  @override
  String? getProperty(String key) => properties[key];

  // ─── MdkPlayerLike: Buffer configuration ───

  int bufferMin = 0;
  int bufferMax = 0;
  bool bufferDrop = false;

  @override
  void setBufferRange({required int min, required int max, required bool drop}) {
    bufferMin = min;
    bufferMax = max;
    bufferDrop = drop;
  }

  @override
  void setRange({required int from, int to = -1}) {
    // no-op in fake
  }

  // ─── MdkPlayerLike: Video properties ───

  @override
  void setVideoEffect(Object? effect, List<double> values) {
    // no-op in fake
  }

  @override
  void setAspectRatio(double ratio) {
    // no-op in fake
  }

  @override
  void rotate(int degree) {
    // no-op in fake
  }

  // ─── MdkPlayerLike: Event streams ───

  @override
  Stream<dynamic> get onStateChanged => _stateController.stream;

  @override
  Stream<dynamic> get onMediaStatus => _statusController.stream;

  /// 模拟 mdk 状态变化事件 — 供测试触发回调
  void emitStateChanged(dynamic newValue) {
    _stateController.add(_FakeStateChangedEvent(newValue));
  }

  /// 模拟 mdk 媒体状态事件 — 供测试触发回调
  void emitMediaStatus(dynamic newValue) {
    _statusController.add(_FakeMediaStatusEvent(newValue));
  }

  // ─── MdkPlayerLike: Lifecycle ───

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    textureIdNotifier.dispose();
    _stateController.close();
    _statusController.close();
  }

  bool get isDisposed => _disposed;
}

/// 简化的 FakeMediaInfo — 模拟 mdk.MediaInfo 结构
///
/// 不 import mdk.MediaInfo，通过动态类型匹配 MediaOpener 的访问模式。
class FakeMdkMediaInfo {
  final int duration;
  final List<FakeVideoTrack>? video;
  final List<FakeAudioTrack>? audio;
  final List<FakeSubtitleTrack>? subtitle;

  FakeMdkMediaInfo({
    this.duration = 60000,
    this.video,
    this.audio,
    this.subtitle,
  });
}

/// 模拟 mdk 视频轨道
class FakeVideoTrack {
  final FakeCodecInfo codec;
  FakeVideoTrack({required this.codec});
}

/// 模拟 mdk 编解码信息
class FakeCodecInfo {
  final int width;
  final int height;
  final double par;
  final String codec;
  final int channels;
  final int index;

  FakeCodecInfo({
    this.width = 1920,
    this.height = 1080,
    this.par = 1.0,
    this.codec = 'h264',
    this.channels = 2,
    this.index = 0,
  });
}

/// 模拟 mdk 音频轨道
class FakeAudioTrack {
  final FakeCodecInfo codec;
  final int index;
  final Map<String, String> metadata;

  FakeAudioTrack({
    required this.codec,
    this.index = 0,
    this.metadata = const {},
  });
}

/// 模拟 mdk 字幕轨道
class FakeSubtitleTrack {
  final int index;
  final Map<String, String> metadata;

  FakeSubtitleTrack({
    this.index = 0,
    this.metadata = const {},
  });
}

/// 模拟 mdk 状态变化事件 — 匹配 FvpCallbackHandler.mapMdkState 的访问模式
class _FakeStateChangedEvent {
  final dynamic newValue;
  _FakeStateChangedEvent(this.newValue);
}

/// 模拟 mdk 媒体状态事件 — 匹配 FvpCallbackHandler.onMediaStatus 的访问模式
class _FakeMediaStatusEvent {
  final dynamic newValue;
  _FakeMediaStatusEvent(this.newValue);
}
