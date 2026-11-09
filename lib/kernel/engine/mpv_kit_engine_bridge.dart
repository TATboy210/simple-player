// ignore_for_file: invalid_use_of_visible_for_testing_member

part of 'mpv_kit_engine.dart';

/// mpv 状态/事件 → ValueNotifier 桥接 — 订阅 MpvState 流与 mpv 事件.
///
/// Bridges [Player] property streams and mpv events into the engine's
/// notifiers. 只订阅有生产消费者的信号; 无消费者的 buffering / 缓冲位置 /
/// 字幕文本 / 宽高比不再观察 (少三条属性订阅 + 对应主线程回流).
extension _MpvKitBridge on _MpvKitState {
  /// 订阅 MpvState 流 (`.stream` 不回放当前值; 构造时核心尚未装载媒体,
  /// 初值即各 notifier 默认值).
  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subscriptions.add(
      stream.listen((v) {
        if (!_disposed) onData(v);
      }),
    );
  }

  void _subscribe() {
    final p = _player;
    _listen(p.position.stream, (d) => _position.value = d.inMilliseconds);
    _listen(p.duration.stream, (d) {
      _duration.value = d.inMilliseconds;
      _rebuildMediaInfo();
    });
    _listen(p.volume.stream, _onMpvVolume);
    _listen(p.speed.stream, (r) => _playbackSpeed.value = r);
    _listen(p.paused.stream, (paused) {
      // 无文件 (idle) 时的 pause 变化与播放态无关.
      if (!p.idle.value) _onPlaying(!paused);
    });
    _listen(p.tracks.stream, (t) {
      _tracks = t;
      _rebuildMediaInfo();
      // K4-b: mediaInfo 已是新表后再通知.
      _trackTableChanged.add(null);
    });
    // 视频链就绪 = file-scoped 属性重放的权威信号.
    _listen(p.videoParams.stream, (vp) {
      _rebuildMediaInfo();
      if (vp != null) _reapplyFileScopedProps();
    });
    _listen(p.playlist.stream, (_) => _scheduleQueueFlush());
    _listen(p.mpv.observeProperty('playlist-playing-pos'), (v) {
      // 切曲间隙的 -1 不覆盖当前条目 (镜像只认有效播放位置).
      if (v is int && v >= 0) _playingPos = v;
      _scheduleQueueFlush();
    });
    // 实际硬解路径 (d3d11va/videotoolbox/vaapi/no) — "no" = CPU 软解, 是
    // 其他机器卡顿的首要嫌疑; 每次变化落盘 environment.txt.
    _listen(p.mpv.observeProperty('hwdec-current'), (v) {
      if (v is String && v.isNotEmpty) {
        RuntimeEnvironmentReport.I.record('decode.hwdec', v);
      }
    });
    _listen(p.mpv.events, _onEvent);
    _listen(p.errors, _onPlaybackError);
    // 4K 排障: info 级才有 "Using hardware decoding" 等解码路径实锤.
    p.setLogLevel('info');
    _listen(p.logs, _onLog);
  }

  void _onEvent(MpvEventData e) {
    switch (e) {
      case StartFileEvent():
        _onPlaying(!_player.paused.value);
      case FileLoadedEvent():
        _openFailureBreaker.reset();
        _reapplyFileScopedProps();
      case EndFileEvent(reason: EndFileReason.eof):
        _onCompleted();
      default:
        break;
    }
  }

  /// 播放/暂停转换. EOF 抢占期 (_completing) 的 paused 不覆盖完成态.
  void _onPlaying(bool playing) {
    if (playing) {
      _completing = false;
      // WASAPI 首播 re-sync: 设备可能首播才就绪, 幂等重写 volume+mute.
      if (_volumeResync.consumeOnPlaying()) {
        _writeMpvVolume('volumeResync', _volume.value);
        _applyMuteProperty(_isMuted.value);
      }
      if (_state.value != MediaState.playing &&
          _state.value != MediaState.opening) {
        _state.value = MediaState.playing;
      }
    } else {
      if (_completing) return;
      if (_state.value == MediaState.playing) _state.value = MediaState.paused;
    }
  }

  void _onCompleted() {
    _completing = true;
    _state.value = MediaState.completed;
    // shuffle 的 EOF 续播 — 随机覆盖层再定向 (loopAll/loopSingle 走 mpv 原生).
    if (_playMode.value == PlayMode.shuffle) _autoAdvanceShuffle();
  }

  void _onPlaybackError(MpvPlaybackError e) {
    // 按 playlist-entry-id 精确取失败条目 (队列镜像经微任务合并, 同批事件
    // 内尚未更新); 取不到再退回镜像当前项.
    final failedPath =
        _player.playlist.value
            .where((entry) => entry.id == e.playlistEntryId)
            .map((entry) => entry.filename)
            .firstOrNull ??
        _currentQueuePath();
    // 连续失败熔断 — 终止 mpv 自动推进的连锁失败 (实机: 90s 207 条).
    if (_openFailureBreaker.registerFailure()) {
      unawaited(stop());
      _lastError.value = UnknownError(
        '连续 ${_openFailureBreaker.threshold} 个文件打开失败, 已停止播放. '
        '最后失败: ${e.message}',
        e,
        ErrorContext(
          action: 'stream.error.circuit-break',
          module: 'MpvKitEngine',
          path: failedPath,
        ),
      );
      return;
    }
    unawaited(_publishPlaybackError(e, failedPath));
  }

  /// 异步判定失败条目是否存在后发布 lastError.
  ///
  /// `loadingFailed` 需区分"文件不存在"与其他装载失败; 存在性探测改走
  /// 异步 `File.exists`, 不在 UI isolate 上做同步磁盘 I/O (网络盘/休眠盘
  /// 上同步 stat 可阻塞数秒). 代价: 错误发布晚一个 I/O 往返, 期间若引擎
  /// 已 dispose 则放弃发布.
  Future<void> _publishPlaybackError(
    MpvPlaybackError e,
    String? failedPath,
  ) async {
    var exists = true;
    if (failedPath != null && e.error == MpvError.loadingFailed) {
      try {
        exists = await File(failedPath).exists();
      } on FileSystemException {
        // 探测本身失败 (权限/驱动器离线) — 按"存在"处理, 不误报 fileNotFound.
        exists = true;
      }
    }
    if (_disposed) return;
    _lastError.value = playerErrorFromMpv(
      e,
      path: failedPath,
      fileExists: (_) => exists,
    );
  }

  /// mpv 内部日志: warn/error 全量 + info 级解码路径白名单.
  void _onLog(LogMessageEvent entry) {
    if (entry.level != 'error' && entry.level != 'warn') {
      final text = entry.text;
      final isDiag =
          entry.level == 'info' &&
          (text.contains('ardware decoding') ||
              text.contains('hwdec') ||
              text.contains('VO ') ||
              text.contains('video output'));
      if (!isDiag) return;
    }
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.d(
      'mpv[${entry.level}] ${entry.prefix}: ${entry.text.trimRight()}',
      context: {'failedPath': _currentQueuePath()},
    );
  }

  /// 清空已卸载媒体的派生状态, 防止空置 UI 渲染旧文件信息.
  void _clearLoadedMediaState() {
    _hasMedia = false;
    _position.value = 0;
    _duration.value = 0;
    _tracks = const [];
    _mediaInfo = const MediaInfo();
  }

  void _rebuildMediaInfo() {
    final codec = tracksOfType(
      _tracks,
      MpvTrackType.video,
    ).where((t) => t.selected).map((t) => t.codec ?? '').firstOrNull;
    _mediaInfo = MediaInfo(
      duration: _duration.value,
      video: videoInfoFromMpv(_player.videoParams.value, codec: codec ?? ''),
      audioTracks: audioTracksFromMpv(_tracks),
      subtitleTracks: subtitleTracksFromMpv(_tracks),
    );
  }
}
