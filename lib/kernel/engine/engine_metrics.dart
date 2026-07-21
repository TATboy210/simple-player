/// 引擎健康指标 — 轻量计数器，暴露引擎层性能数据
///
/// Lightweight counters for engine-layer performance data.
/// Counters accumulate on each engine operation; call [reset] to zero them.
/// UI layer can display these via the Settings "Performance" tab.
class EngineMetrics {
  // ─── 播放统计 ───

  /// 丢帧总数（D3D11 渲染管线报告）
  ///
  /// Total frames dropped, reported by the D3D11 render pipeline.
  int framesDropped = 0;

  /// 解码错误次数
  ///
  /// Number of decode errors encountered during playback.
  int decodeErrors = 0;

  /// 缓冲欠载次数（播放因缓冲不足而暂停）
  ///
  /// Number of buffer underruns (playback stalls due to insufficient data).
  int bufferUnderruns = 0;

  // ─── Seek 统计 ───

  /// 累计 seek 耗时（用于计算平均值）
  Duration _totalSeekTime = Duration.zero;

  /// seek 次数
  int _seekCount = 0;

  /// 平均 seek 耗时
  ///
  /// Returns the average seek duration, or [Duration.zero] if no seeks recorded.
  Duration get averageSeekTime =>
      _seekCount > 0 ? _totalSeekTime ~/ _seekCount : Duration.zero;

  // ─── Open 统计 ───

  /// open() 尝试次数
  ///
  /// Total number of open attempts (success + failure).
  int openAttempts = 0;

  /// open() 失败次数
  ///
  /// Number of open attempts that ended in failure.
  int openFailures = 0;

  /// open() 成功率（0.0–1.0）
  ///
  /// Returns the open success ratio, or `0.0` if no attempts recorded.
  double get openSuccessRate =>
      openAttempts > 0 ? (openAttempts - openFailures) / openAttempts : 0;

  // ─── 记录方法 ───

  /// 记录一次 open 操作
  ///
  /// Records a single open attempt.
  /// - [success]: `true` if the open succeeded, `false` otherwise.
  void recordOpen({required bool success}) {
    openAttempts++;
    if (!success) openFailures++;
  }

  /// 记录一次 seek 操作
  ///
  /// Records a seek operation with its [elapsed] duration.
  void recordSeek(Duration elapsed) {
    _seekCount++;
    _totalSeekTime += elapsed;
  }

  /// 记录一次丢帧
  ///
  /// Records [count] dropped frames (default 1).
  void recordFrameDrop([int count = 1]) {
    framesDropped += count;
  }

  /// 记录一次解码错误
  ///
  /// Increments the decode error counter by one.
  void recordDecodeError() {
    decodeErrors++;
  }

  /// 记录一次缓冲欠载
  ///
  /// Increments the buffer underrun counter by one.
  void recordBufferUnderrun() {
    bufferUnderruns++;
  }

  /// 重置所有计数器（供测试使用）
  ///
  /// Resets all counters to zero. Intended for test isolation.
  void reset() {
    framesDropped = 0;
    decodeErrors = 0;
    bufferUnderruns = 0;
    _totalSeekTime = Duration.zero;
    _seekCount = 0;
    openAttempts = 0;
    openFailures = 0;
  }

  /// 导出为 Map（供 UI 展示或调试导出）
  ///
  /// Returns a JSON-serialisable [Map] of all metrics.
  /// Keys: `framesDropped`, `decodeErrors`, `bufferUnderruns`,
  /// `averageSeekTimeMs`, `openAttempts`, `openFailures`, `openSuccessRate`.
  Map<String, Object> toJson() => {
    'framesDropped': framesDropped,
    'decodeErrors': decodeErrors,
    'bufferUnderruns': bufferUnderruns,
    'averageSeekTimeMs': averageSeekTime.inMilliseconds,
    'openAttempts': openAttempts,
    'openFailures': openFailures,
    'openSuccessRate': (openSuccessRate * 100).toStringAsFixed(1),
  };
}
