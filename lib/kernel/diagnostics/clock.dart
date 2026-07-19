/// 时钟抽象 — 将 DateTime.now() 封装为可注入接口。
///
/// Abstract clock. Production code uses [SystemClock], tests use [FakeClock]
/// to control time progression without real wall-clock dependency.
abstract class Clock {
  /// 当前时间。
  DateTime now();
}

/// 生产环境时钟 — 委托给 DateTime.now()。
///
/// Production implementation. Const constructor, zero state.
final class SystemClock implements Clock {
  /// const 构造 — 无状态, 支持编译时常量。
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 测试用时钟 — 可变 DateTime, 时间完全可控。
///
/// Fake for testing. Tests set [now] to simulate time progression
/// without real delays.
final class FakeClock implements Clock {
  /// 构造 — 初始时间默认 epoch。
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime(2026);

  DateTime _now;

  /// 设置当前时间 (测试用)。
  set currentTime(DateTime t) => _now = t;

  @override
  DateTime now() => _now;
}
