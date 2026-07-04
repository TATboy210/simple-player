/// 引擎健康指标 — 轻量计数器，暴露引擎层性能数据
///
/// UI 层可通过设置面板"性能"tab 展示这些指标。
/// 计数器在每次引擎操作时累加，[reset] 可清零（供测试使用）。
class EngineMetrics {
  // ─── 播放统计 ───

  /// 丢帧总数（D3D11 渲染管线报告）
  int framesDropped = 0;

  /// 解码错误次数
  int decodeErrors = 0;

  /// 缓冲欠载次数（buffer underrun = 播放因缓冲不足而暂停）
  int bufferUnderruns = 0;

  // ─── Seek 统计 ───

  /// 累计 seek 耗时（用于计算平均值）
  Duration _totalSeekTime = Duration.zero;

  /// seek 次数
  int _seekCount = 0;

  /// 平均 seek 耗时
  Duration get averageSeekTime =>
      _seekCount > 0 ? _totalSeekTime ~/ _seekCount : Duration.zero;

  // ─── Open 统计 ───

  /// open() 尝试次数
  int openAttempts = 0;

  /// open() 失败次数
  int openFailures = 0;

  /// open() 成功率
  double get openSuccessRate =>
      openAttempts > 0 ? (openAttempts - openFailures) / openAttempts : 0;

  // ─── 记录方法 ───

  /// 记录一次 open 操作
  void recordOpen({required bool success}) {
    openAttempts++;
    if (!success) openFailures++;
  }

  /// 记录一次 seek 操作
  void recordSeek(Duration elapsed) {
    _seekCount++;
    _totalSeekTime += elapsed;
  }

  /// 记录一次丢帧
  void recordFrameDrop([int count = 1]) {
    framesDropped += count;
  }

  /// 记录一次解码错误
  void recordDecodeError() {
    decodeErrors++;
  }

  /// 记录一次缓冲欠载
  void recordBufferUnderrun() {
    bufferUnderruns++;
  }

  /// 重置所有计数器（供测试使用）
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
