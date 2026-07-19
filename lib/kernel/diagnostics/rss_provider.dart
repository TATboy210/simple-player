import 'dart:io';

/// RSS 内存读取抽象 — 将 ProcessInfo.currentRss 封装为可注入接口。
///
/// Abstract RSS reader. Wraps [ProcessInfo.currentRss] behind an interface
/// so production code uses [ProcessInfoRssProvider] and tests use [FakeRssProvider].
abstract class RssProvider {
  /// 当前进程 RSS (Resident Set Size) 字节数。
  int get currentRss;
}

/// 生产环境 RSS 读取 — 委托给 dart:io ProcessInfo.currentRss。
///
/// Production implementation. Const constructor, zero state.
final class ProcessInfoRssProvider implements RssProvider {
  /// const 构造 — 无状态, 支持编译时常量。
  const ProcessInfoRssProvider();

  @override
  int get currentRss => ProcessInfo.currentRss;
}

/// 测试用 RSS 读取 — 可变 int 值, 无 ProcessInfo 依赖。
///
/// Fake for testing. Accepts a mutable [value] so tests can simulate
/// RSS changes without real process memory.
final class FakeRssProvider implements RssProvider {
  /// 构造 — 初始值默认 0。
  FakeRssProvider([this._value = 0]);

  int _value;

  /// 设置当前 RSS 值 (测试用)。
  set value(int v) => _value = v;

  @override
  int get currentRss => _value;
}
