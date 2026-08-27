import 'kernel_logger.dart';

/// 启动计时器 — 纯诊断工具（单一职责：测量并记录启动时序）。
///
/// 打点式 API：线性启动序列中按序调用 [mark]，相邻打点之差即该阶段耗时；
/// 全部就绪后调用 [ready]，以单条结构化日志输出逐阶段耗时（与
/// ResizeFrameMetrics 的 toContext 同风格，便于 grep 与机器解析）。
///
/// 不持有任何 UI 状态 — 原 StartupCoordinator 的进度广播随生产不可达的
/// 进度 Splash 一并移除；窗口初始化失败等用户可见错误态由 PlayerFeature /
/// App 自行渲染，与本计时器无关。
///
/// 用法：
/// ```dart
/// final timeline = StartupTimeline();
/// timeline.mark(StartupTimeline.phaseInfrastructure); // 窗口服务就绪后
/// timeline.mark(StartupTimeline.phasePlayerInit);     // 播放器服务就绪后
/// timeline.ready();                                   // 输出 Timeline 日志
/// ```
final class StartupTimeline {
  /// 阶段锚点常量 — 避免调用方散落裸字符串导致口径漂移。
  static const phaseInfrastructure = 'infrastructure';
  static const phasePlayerInit = 'playerInit';

  StartupTimeline({KernelLogger? logger}) : _logger = logger ?? KernelLogger.I;

  final KernelLogger _logger;

  final Stopwatch _stopwatch = Stopwatch()..start();

  /// 有序打点表 — Dart Map 保持插入序，遍历即可还原阶段先后。
  final Map<String, int> _marks = {};

  bool _reported = false;

  /// 记录一个时间点。重复标记同一阶段以首点为准；[ready] 后为 no-op。
  void mark(String phase) {
    if (_reported) return;
    _marks.putIfAbsent(phase, () => _stopwatch.elapsedMilliseconds);
  }

  /// 结束计时并输出结构化启动耗时日志；重复调用为 no-op。
  ///
  /// side effect: 停止内部 Stopwatch 并向 kernel logger 发出一条 info 记录，
  /// context 字段形如 `<phase>Ms` + `totalMs`（保留一位小数）。
  void ready() {
    if (_reported) return;
    _reported = true;

    var previousMs = 0;
    final context = <String, Object?>{};
    for (final entry in _marks.entries) {
      context['${entry.key}Ms'] = entry.value - previousMs;
      previousMs = entry.value;
    }
    _stopwatch.stop();
    context['totalMs'] = _stopwatch.elapsedMicroseconds / 1000;

    _logger.info('startup_timeline', context: context);
  }
}
