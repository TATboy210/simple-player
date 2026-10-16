// ignore_for_file: invalid_use_of_visible_for_testing_member

part of 'mpv_kit_engine.dart';

/// QueueControl 实现 — 队列权威在 mpv 原生 playlist, 引擎只做投影 + 乐观镜像.
///
/// Queue operations of [MpvKitEngine]. Every edit updates the mirror
/// optimistically and touches [MpvKitEngine.queueRevision] once; the mpv
/// `playlist` / `playlist-playing-pos` observers overwrite it idempotently.
extension _MpvKitQueue on MpvKitEngine {
  // ─── 回流镜像 ───

  /// 合并同一批 mpv 事件里的 playlist / playing-pos 变化, 微任务单发.
  void _scheduleQueueFlush() {
    if (_queueFlushScheduled) return;
    _queueFlushScheduled = true;
    scheduleMicrotask(() {
      _queueFlushScheduled = false;
      if (_disposed) return;
      final entries = _player.playlist.value;
      final paths = List<String>.unmodifiable([
        for (final e in entries) e.filename,
      ]);
      // 空列表 (stop/清空) = "无当前条目"; 有效 index 取最近一次 >=0 值.
      if (entries.isEmpty) _playingPos = -1;
      final index = entries.isEmpty
          ? -1
          : _playingPos.clamp(-1, entries.length - 1);
      if (_sameContent(_queuePaths.value, paths) &&
          _queueIndex.value == index) {
        return; // 乐观镜像已到位 — 不重复通知.
      }
      _queuePaths.value = paths;
      _queueIndex.value = index;
      if (!_queueEditInProgress) _touchQueueRevision();
    });
  }

  /// 队列代数递增 — paths/index 全部赋值完成后调用 (单通知点契约).
  void _touchQueueRevision() => _queueRevision.value++;

  /// 当前队列条目路径 (越界/空返回 null) — 错误事件的失败路径取材处.
  String? _currentQueuePath() {
    if (_disposed) return null;
    final paths = _queuePaths.value;
    final index = _queueIndex.value;
    if (index < 0 || index >= paths.length) return null;
    return paths[index];
  }

  // ─── 装载 / 追加 / 移除 / 排序 ───

  Future<OpenResult> _openPlaylist(List<String> paths, int startIndex) async {
    if (paths.isEmpty) {
      final error = FileError(
        FileErrorCode.pathEmpty,
        '队列为空, 无法装载',
        null,
        ErrorContext(action: 'openPlaylist', module: 'MpvKitEngine'),
      );
      _lastError.value = error;
      return OpenError(error);
    }
    final gen = ++_operationGeneration;
    _state.value = MediaState.opening;
    _isBuffering.value = true;
    _queueEditInProgress = true;
    final clampedStart = startIndex.clamp(0, paths.length - 1);
    try {
      final mpv = _player.mpv;
      mpv.setProperty('pause', true); // 起播由调用方显式 play() 控制.
      mpv.command(['stop']); // 清空旧队列 (stop 同时清 playlist).
      // 追加命令按序排队, 并发等待 — 免逐条往返 (大目录毫秒级).
      await Future.wait([
        for (final path in paths)
          mpv.commandAsync(['loadfile', path, 'append']).result,
      ]);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
      mpv.command(['playlist-play-index', clampedStart]);
      _queuePaths.value = List.unmodifiable(paths);
      _queueIndex.value = clampedStart;
      _playingPos = clampedStart;
      _hasMedia = true;
      _armVolumeResync();
      _state.value = MediaState.idle;
      return OpenSuccess(_mediaInfo);
    } on MpvException catch (error, stackTrace) {
      return _openFailed(gen, 'openPlaylist', '装载播放队列失败', error, stackTrace);
    } finally {
      if (_isCurrentGeneration(gen)) _isBuffering.value = false;
      _queueEditInProgress = false;
      if (!_disposed) _touchQueueRevision();
    }
  }

  Future<void> _appendToQueue(List<String> paths) async {
    _queueEditInProgress = true;
    try {
      // loadfile append — 原子追加, 不打断当前播放.
      await Future.wait([
        for (final path in paths)
          _player.mpv.commandAsync(['loadfile', path, 'append']).result,
      ]);
      // index 不变; 空队列首次追加保持 -1, 由 jumpTo/回流纠正.
      _queuePaths.value = List.unmodifiable([..._queuePaths.value, ...paths]);
    } on MpvException catch (error, stackTrace) {
      _reportQueueError('appendToQueue', '追加播放队列失败', error, stackTrace);
    } finally {
      _queueEditInProgress = false;
      if (!_disposed) _touchQueueRevision();
    }
  }

  void _removeFromQueue(int index) {
    final paths = _queuePaths.value;
    if (index < 0 || index >= paths.length) return; // 越界 no-op (接口契约)
    try {
      _player.remove(index);
      _applyRemoveMirror(paths, index);
      _touchQueueRevision();
    } on MpvException catch (error, stackTrace) {
      _reportQueueError('removeFromQueue', '移除队列条目失败', error, stackTrace);
    }
  }

  void _removeFromQueueBatch(Set<int> indices) {
    final count = _queuePaths.value.length;
    // 越界过滤 + 降序 — 前置索引不受删除位移影响.
    final valid = indices.where((i) => i >= 0 && i < count).toList()
      ..sort((a, b) => b.compareTo(a));
    if (valid.isEmpty) return;
    _queueEditInProgress = true;
    try {
      for (final index in valid) {
        _player.remove(index);
        _applyRemoveMirror(_queuePaths.value, index);
      }
    } on MpvException catch (error, stackTrace) {
      _reportQueueError(
        'removeFromQueueBatch',
        '批量移除队列条目失败',
        error,
        stackTrace,
      );
    } finally {
      _queueEditInProgress = false;
      _touchQueueRevision();
    }
  }

  /// 删除单条目的乐观镜像平移 — 正在播放条目被删时 mpv 自动跳转, 精确
  /// index 由回流纠正, 这里只保证不越界. [paths] 须为删除前快照.
  void _applyRemoveMirror(List<String> paths, int index) {
    final remaining = [...paths]..removeAt(index);
    final current = _queueIndex.value;
    var nextIndex = current;
    if (current > index) {
      nextIndex = current - 1;
    } else if (current == index) {
      nextIndex = remaining.isEmpty ? -1 : index.clamp(0, remaining.length - 1);
    }
    _queuePaths.value = List.unmodifiable(remaining);
    _queueIndex.value = nextIndex;
    if (nextIndex >= 0) _playingPos = nextIndex;
  }

  Future<void> _sortQueue(List<String> targetOrder) async {
    final current = _queuePaths.value;
    final moves = planPlaylistMoves(current, targetOrder);
    if (moves.isEmpty) return; // 恒等排列/非排列 — no-op 防御
    final currentIndex = _queueIndex.value;
    final playingPath = (currentIndex >= 0 && currentIndex < current.length)
        ? current[currentIndex]
        : null;
    final targetIndex = playingPath == null
        ? -1
        : targetOrder.indexOf(playingPath);
    _queueEditInProgress = true;
    try {
      // playlist-move 保留条目 current 标记, 播放不中断; mpv 命令串行保序.
      for (final move in moves) {
        _player.move(move.from, move.to);
      }
      _queuePaths.value = List.unmodifiable(targetOrder);
      _queueIndex.value = targetIndex;
      if (targetIndex >= 0) _playingPos = targetIndex;
    } on MpvException catch (error, stackTrace) {
      _reportQueueError('sortQueue', '排序队列失败', error, stackTrace);
    } finally {
      // 清流窗 (v0.0.12 V1): 抑制多保持一轮事件循环, 让 move 积压的
      // playlist 回流在抑制期内落地 — 只写镜像不发 revision; 窗末重申
      // 权威 index 后单发, Coordinator 不会收到"新序+旧索引"陈旧帧.
      await Future<void>.delayed(Duration.zero);
      if (!_disposed && _sameContent(_queuePaths.value, targetOrder)) {
        _queueIndex.value = targetIndex;
      }
      _queueEditInProgress = false;
      if (!_disposed) _touchQueueRevision();
    }
  }

  void _reportQueueError(
    String action,
    String label,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_disposed) return;
    _lastError.value = UnknownError(
      '$label: $error',
      error,
      ErrorContext(
        action: action,
        module: 'MpvKitEngine',
        callbackStackTrace: stackTrace,
      ),
    );
  }

  // ─── 跳转 / 步进 / 模式 ───

  bool _jumpTo(int index) {
    final count = _queuePaths.value.length;
    if (index < 0 || index >= count) return false; // mpv 不查边界, 防御前置
    _completing = false;
    _queueIndex.value = index;
    _playingPos = index;
    _touchQueueRevision();
    try {
      // 跳转即播放 — "点击列表条目直接播放"的 UI 语义.
      _player.jump(index);
      _player.play();
      return true;
    } on MpvException catch (error, stackTrace) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '跳转队列条目失败: $error',
        error,
        ErrorContext(
          action: 'jumpTo',
          module: 'MpvKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  /// 上一个/下一个统一步进 — 边界语义按 [playMode] 裁定, 全部走 jumpTo.
  bool _stepQueue({required bool forward}) {
    final count = _queuePaths.value.length;
    if (count == 0) return false;
    final current = _queueIndex.value;
    if (current < 0) {
      // 未播放: 步进视为从头/从尾开始播.
      _jumpTo(forward ? 0 : count - 1);
      return true;
    }
    if (_playMode.value == PlayMode.shuffle) {
      return _stepShuffle(forward: forward, current: current);
    }
    final target = forward ? current + 1 : current - 1;
    // 越界回绕 — loopSingle 只约束自然播完, 用户主动切曲照常回绕.
    _jumpTo(target >= 0 && target < count ? target : (forward ? 0 : count - 1));
    return true;
  }

  /// shuffle 步进 — next 随机 (当前曲入历史栈), previous 弹栈回溯.
  bool _stepShuffle({required bool forward, required int current}) {
    final queue = _queuePaths.value;
    final currentPath = queue[current];
    if (forward) {
      ShufflePolicy.pushHistory(_shuffleHistory, currentPath);
      final next = ShufflePolicy.pickShuffleNext(
        queue: queue,
        current: currentPath,
        recent: _shuffleHistory.toList(),
        random: _rng,
      );
      // 单文件队列 — 唯一候选即当前曲, 重播.
      _jumpTo(next == null ? current : queue.indexOf(next));
      return true;
    }
    while (_shuffleHistory.isNotEmpty) {
      final candidate = _shuffleHistory.removeLast();
      final index = queue.indexOf(candidate);
      if (index >= 0 && index != current) {
        _jumpTo(index);
        return true;
      }
    }
    final target = current - 1; // 栈空 — 线性回绕兜底
    _jumpTo(target >= 0 ? target : queue.length - 1);
    return true;
  }

  /// shuffle EOF 自动续播 — 当前曲入历史栈后随机选下一曲.
  void _autoAdvanceShuffle() {
    final queue = _queuePaths.value;
    if (queue.isEmpty) return;
    final currentIndex = _queueIndex.value;
    final currentPath = (currentIndex >= 0 && currentIndex < queue.length)
        ? queue[currentIndex]
        : null;
    if (currentPath != null) {
      ShufflePolicy.pushHistory(_shuffleHistory, currentPath);
    }
    final next = ShufflePolicy.pickShuffleNext(
      queue: queue,
      current: currentPath,
      recent: _shuffleHistory.toList(),
      random: _rng,
    );
    if (next == null) {
      if (currentPath != null) _jumpTo(currentIndex);
      return;
    }
    _jumpTo(queue.indexOf(next));
  }

  void _setPlayMode(PlayMode mode) {
    _playMode.value = mode; // 引擎为模式单一数据源, 先记后映射.
    try {
      switch (mode) {
        case PlayMode.loopAll:
          _player.setLoopMode(MpvLoopMode.playlist);
        case PlayMode.loopSingle:
          _player.setLoopMode(MpvLoopMode.file);
        case PlayMode.shuffle:
          // 随机 = 播放顺序覆盖层, 列表永不乱序; 关掉 mpv 线性循环, EOF
          // 续播由 _onCompleted 随机再定向.
          _shuffleHistory.clear();
          _player.setLoopMode(MpvLoopMode.none);
      }
    } on MpvException catch (error, stackTrace) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '设置播放模式失败: $error',
        error,
        ErrorContext(
          action: 'setPlayMode',
          module: 'MpvKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
    }
  }
}

/// 逐元素内容等价 — 镜像是否已收敛为目标全序.
bool _sameContent(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
