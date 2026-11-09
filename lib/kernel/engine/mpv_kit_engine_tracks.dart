// ignore_for_file: invalid_use_of_visible_for_testing_member

part of 'mpv_kit_engine.dart';

/// TrackControl + SubtitleConfig 实现 — 音轨/字幕轨切换、外挂字幕、延迟.
///
/// Track and subtitle facets of [MpvKitEngine]; 轨道索引是 mpv_kit_tracks.dart
/// 里的"同类型内序号", 与 mpv 轨道 id 的换算集中在那里.
mixin _MpvKitTracks on _MpvKitState {
  @override
  List<AudioTrackInfo> getAudioTracks() => audioTracksFromMpv(_tracks);

  @override
  void switchAudioTrack(int trackId) {
    if (_disposed) return;
    final id = mpvTrackIdAt(_tracks, MpvTrackType.audio, trackId);
    if (id == null) return;
    _guard(
      'switchAudioTrack',
      () => _player.selectTrack(MpvTrackType.audio, id),
    );
  }

  @override
  List<int> get activeAudioTracks =>
      activeIndexOf(_tracks, MpvTrackType.audio, _player.audioTrack.value);

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => subtitleTracksFromMpv(_tracks);

  @override
  void switchSubtitleTrack(int trackId) {
    if (_disposed) return;
    // K4-a: -1 = 关闭字幕偏好 (显式 sid=no, 否则下个文件自动回来).
    if (trackId == -1) {
      _guard(
        'switchSubtitleTrack',
        () => _player.selectTrack(MpvTrackType.sub, null),
      );
      return;
    }
    final id = mpvTrackIdAt(_tracks, MpvTrackType.sub, trackId);
    if (id == null) return;
    _guard(
      'switchSubtitleTrack',
      () => _player.selectTrack(MpvTrackType.sub, id),
    );
  }

  @override
  void toggleSubtitle() {
    if (_disposed) return;
    final off = _player.subtitleTrack.value == null;
    _guard(
      'toggleSubtitle',
      () => _player.mpv.setPropertyString('sid', off ? 'auto' : 'no'),
    );
  }

  @override
  void setExternalSubtitle(String path) {
    if (_disposed) return;
    unawaited(
      _player.addSubtitle(path).catchError((Object error) {
        _reportPropertyError('sub-add', path, error);
      }),
    );
  }

  @override
  void setSubtitleDelay(int delay) {
    if (_disposed) return;
    _subtitleDelayMs = delay;
    _applyMpvProperty(MpvPropertyMapper.mapDelay('sub-delay', delay));
  }

  @override
  void setAudioDelay(int delay) {
    if (_disposed) return;
    _audioDelayMs = delay;
    _applyMpvProperty(MpvPropertyMapper.mapDelay('audio-delay', delay));
  }

  @override
  int get subtitleDelay => _subtitleDelayMs;

  @override
  int get audioDelay => _audioDelayMs;

  @override
  List<int> get activeSubtitleTracks =>
      activeIndexOf(_tracks, MpvTrackType.sub, _player.subtitleTrack.value);

  /// 控制栏避让: 把字幕底边距抬高 [inset] 逻辑像素.
  ///
  /// 字幕由 libass 画进视频纹理, Flutter 侧无字幕组件可加 padding — 改写
  /// mpv `sub-margin-y` (缩放像素, 以 720p 窗口高度为基准), 换算:
  /// `22 + inset × 720 / surfaceHeight`. [inset] 为 0 即恢复默认边距.
  /// side effect: 值变化时写 mpv 属性 (触发一次字幕重画).
  void setSubtitleBottomInset(double inset, double surfaceHeight) {
    if (_disposed || surfaceHeight <= 0) return;
    final margin =
        MpvKitEngine._baseSubMarginY +
        (inset.clamp(0, surfaceHeight) *
                MpvKitEngine._subScaleReferenceHeight /
                surfaceHeight)
            .round();
    if (margin == _subMarginY) return;
    _subMarginY = margin;
    _guard(
      'sub-margin-y',
      () => _player.mpv.setPropertyString('sub-margin-y', '$margin'),
    );
  }
}

/// VideoEffectControl + RendererControl 实现 — mpv 属性直通.
///
/// Video effect and renderer facets of [MpvKitEngine]: 值经
/// [MpvPropertyMapper] 映射为 mpv 属性; 新文件装载会重置的属性进
/// file-scoped 缓存并在 `file-loaded` 重放.
mixin _MpvKitEffects on _MpvKitState {
  @override
  void setVideoEffect(VideoEffectType effectType, double value) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapVideoEffect(effectType, value));
  }

  @override
  void rotate(int degrees) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapRotation(degrees));
  }

  @override
  void setAspectRatio(double ratio) {
    if (_disposed) return;
    final property = MpvPropertyMapper.mapAspectRatio(ratio);
    if (property == null) {
      // stretch/cropFill 单属性不可表达 — 诚实降级, 保持原状不伪造.
      _unsupported('setAspectRatio.$ratio');
      return;
    }
    _applyMpvProperty(property);
  }

  @override
  void setDeinterlace(bool enable) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapDeinterlace(enable));
  }

  @override
  void setHardwareDecoding(bool enabled) {
    if (_disposed) return;
    // hwdec 是全局属性 — 新文件装载不重置, 不入缓存.
    _applyMpvProperty(
      MpvPropertyMapper.mapHardwareDecoding(enabled),
      fileScoped: false,
    );
  }
}
