// ignore_for_file: invalid_use_of_visible_for_testing_member

part of 'mpv_kit_engine.dart';

/// PlaybackControl + VolumeControl 实现 — open/play/pause/stop/seek/音量/倍速.
///
/// Playback and volume facets of [MpvKitEngine]. 所有方法在 disposed 后为
/// no-op; 失败经 `lastError` + `state → error` 表达, 不抛向调用方.
mixin _MpvKitPlayback on _MpvKitState {
  @override
  Future<OpenResult> open(String path) async {
    if (_disposed) return const OpenSuperseded();
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _state.value = MediaState.error;
      final error = FileError(
        FileErrorCode.pathEmpty,
        '文件路径为空',
        null,
        ErrorContext(action: 'open', path: trimmed, module: 'MpvKitEngine'),
      );
      _lastError.value = error;
      return OpenError(error);
    }
    final gen = ++_operationGeneration;
    _state.value = MediaState.opening;
    try {
      // play:false — 起播由 PlaybackController 成功后显式 play() 控制.
      await _player.open(trimmed, play: false);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
      _hasMedia = true;
      _armVolumeResync();
      _state.value = MediaState.idle;
      return OpenSuccess(_mediaInfo);
    } on MpvException catch (error, stackTrace) {
      return _openFailed(gen, 'open', '打开失败', error, stackTrace, trimmed);
    }
  }

  @override
  void play() {
    if (_disposed || !_hasMedia) return;
    final s = _state.value;
    if (s == MediaState.opening || s == MediaState.error) return;
    // Dart 状态与 mpv 实际一致地在播才是 no-op — 状态漂移时 (Dart=playing
    // 但 mpv 已暂停) 仍须下发, 否则用户按一次不响应.
    if (s == MediaState.playing && _isMpvPlaying) return;
    _completing = false;
    _state.value = MediaState.playing;
    // 播完 (keep-open=no) 后 mpv 已 idle — 重新播放须重新起播当前条目.
    if (_player.idle.value && _queuePaths.value.isNotEmpty) {
      final index = _queueIndex.value < 0 ? 0 : _queueIndex.value;
      _command(['playlist-play-index', index]);
    }
    _guard('play', _player.play);
  }

  @override
  void pause() {
    if (_disposed || !_hasMedia) return;
    // 以 mpv 实际为准: Dart 状态漂移 (非 playing 但 mpv 在播) 时同样暂停.
    if (_state.value != MediaState.playing && !_isMpvPlaying) return;
    _state.value = MediaState.paused;
    _guard('pause', _player.pause);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _completing = false;
    try {
      _player.stop();
    } on MpvException catch (error, stackTrace) {
      if (!_isCurrentGeneration(generation)) return;
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '停止播放失败: $error',
        error,
        ErrorContext(
          action: 'stop',
          generation: generation,
          module: 'MpvKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      _state.value = MediaState.error;
      return;
    }
    if (!_isCurrentGeneration(generation)) return;
    _clearLoadedMediaState();
    if (_state.value != MediaState.idle) _state.value = MediaState.idle;
  }

  @override
  void togglePlayPause() {
    if (_disposed) return;
    switch (_state.value) {
      case MediaState.opening || MediaState.error:
        return; // not toggleable — no-op
      case MediaState.idle ||
          MediaState.playing ||
          MediaState.paused ||
          MediaState.completed:
        // 方向取 mpv 的实际 pause 属性 — 与控制栏图标同一真相源. 旧实现
        // 按 Dart 镜像状态分支, 两者漂移时首按只"纠正"镜像, 须按第二下.
        _isMpvPlaying ? pause() : play();
    }
  }

  /// mpv 是否真在推进播放: 有已装载文件 (非 idle) 且 pause=false.
  bool get _isMpvPlaying =>
      _hasMedia && !_player.idle.value && !_player.paused.value;

  @override
  Future<void> seekTo(int ms) async {
    if (_disposed) return;
    final dur = _duration.value;
    if (_state.value == MediaState.idle || dur <= 0) return;
    final clamped = ms.clamp(0, dur);
    // 乐观定位: 立即反馈 UI; time-pos 回流纠正.
    _position.value = clamped;
    try {
      // `absolute` 不带 +keyframes: mpv 默认对绝对 seek 走精确 (hr-seek).
      await _player.mpv.commandAsync([
        'seek',
        '${clamped / 1000}',
        'absolute',
      ]).result;
    } on MpvException catch (error) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: $error',
        error,
        ErrorContext(action: 'seek', module: 'MpvKitEngine'),
      );
    }
  }

  @override
  void setVolume(double value) {
    if (_disposed) return;
    final clamped = value.clamp(0.0, 1.0);
    _volume.value = clamped;
    // 穿越 0 边界联动静音 (契约: 0 自动静音, 调高取消).
    if (clamped == 0.0) {
      _isMuted.value = true;
      _applyMuteProperty(true);
    } else if (_isMuted.value) {
      _isMuted.value = false;
      _applyMuteProperty(false);
    }
    // 感知曲线: mpv volume 是立方软增益, 传立方根使滑条位置即感知响度;
    // 下发值入回声窗口, mpv 回显不会再覆写 _volume (见 _onMpvVolume).
    _writeMpvVolume('setVolume', clamped);
  }

  @override
  void setMute(bool mute) {
    if (_disposed) return;
    _isMuted.value = mute;
    _applyMuteProperty(mute);
  }

  @override
  void setPlaybackRate(double rate) {
    if (_disposed) return;
    final clamped = rate.clamp(0.25, 4.0);
    _playbackSpeed.value = clamped;
    _guard('setPlaybackRate', () => _player.setSpeed(clamped));
  }

  @override
  void skipForward([int ms = 10000]) => unawaited(seekTo(_position.value + ms));

  @override
  void skipBack([int ms = 10000]) => unawaited(seekTo(_position.value - ms));
}
