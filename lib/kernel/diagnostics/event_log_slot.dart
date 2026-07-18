/// 事件日志插槽接口 (D9/D10 — 从 EngineEventLog 公开 API 提炼, 脱离具体 EngineEvent 类型)
///
/// Traced from [EngineEventLog]'s ring-buffer surface
/// (engine_event_log.dart:66-102). `entries`/`toJson` are loosened off the
/// concrete `EngineEvent` type to `Map<String, Object?>` (D10) so Phase 19
/// can change the concrete event shape without breaking this interface.
abstract class EventLogSlot {
  /// 追加一条事件记录 (type 为事件类型, data 为可选附加数据)
  void add(String type, [Map<String, Object?>? data]);

  /// 当前所有事件条目 — 松散类型, 未耦合具体 EngineEvent (D10)
  List<Map<String, Object?>> get entries;

  /// 清空所有事件条目
  void clear();

  /// 导出为 JSON 列表
  List<Map<String, Object?>> toJson();

  /// 释放资源 (由 DiagnosticsBundle.dispose() 级联调用)
  void dispose();
}

/// 空实现 EventLogSlot — Phase 16 默认值, add/clear 空操作, 读取返回空列表。
///
/// Null-object implementation: [add]/[clear] no-op, [entries]/[toJson]
/// return const empty lists.
final class NullEventLogSlot implements EventLogSlot {
  const NullEventLogSlot();

  @override
  void add(String type, [Map<String, Object?>? data]) {}

  @override
  List<Map<String, Object?>> get entries => const <Map<String, Object?>>[];

  @override
  void clear() {}

  @override
  List<Map<String, Object?>> toJson() => const <Map<String, Object?>>[];

  @override
  void dispose() {}
}
