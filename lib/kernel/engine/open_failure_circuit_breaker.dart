/// 连续打开失败熔断器 — 队列级连锁失败的保护纯逻辑 (v0.0.6.1).
///
/// Open-failure circuit breaker — protection against cascading queue failure.
///
/// 背景 (实机 error.log 证据): mpv 对打不开的条目会**原生自动跳下一条**;
/// 当目录级访问被阻断时(杀软拦截/盘符断开/文件夹整体不可读), 队列全部
/// 条目连续失败, 形成 90 秒 207 条错误的连锁烧穿 (error-1789485012 系列).
/// 连续 [threshold] 次失败即熔断: 调用方停止自动推进并聚合上报一次,
/// 避免错误洪流与无意义的磁盘/CPU 空转.
///
/// 计数语义: 任何成功装载 (收到 duration 即媒体真正打开) 复位计数;
/// 少量坏文件 (队列里个别损坏条目) 触发 1-2 次失败后遇到好条目即复位,
/// **不会**熔断 — 只有整队列级失败才触发.
class OpenFailureCircuitBreaker {
  OpenFailureCircuitBreaker({this.threshold = 3});

  /// 熔断阈值 — 连续失败达到该次数即触发.
  final int threshold;

  int _count = 0;

  /// 登记一次打开失败 — 返回 true 表示达到阈值, 调用方应熔断
  /// (停止推进 + 聚合上报), 返回 false 表示继续观察.
  bool registerFailure() {
    _count++;
    return _count >= threshold;
  }

  /// 成功装载复位 — 打开成功或收到 duration 均视为恢复.
  void reset() => _count = 0;

  /// 当前连续失败计数 (诊断/测试观测).
  int get count => _count;
}
