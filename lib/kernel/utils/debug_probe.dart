import 'dart:convert';

import 'package:flutter/foundation.dart';

// ─── 编译期开关 ───

/// 是否启用调试探针。release 构建中为 false，所有探针代码被 tree-shake。
const bool _probesEnabled = kDebugMode;

// ─── 数据类 ───

/// 探针事件 — 记录一次操作的标签、耗时、附加上下文。
class ProbeEvent {
  const ProbeEvent({
    required this.label,
    required this.timestamp,
    this.elapsed,
    this.data,
  });

  final String label;
  final Duration? elapsed;
  final Map<String, Object>? data;
  final DateTime timestamp;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'label': label,
      'timestamp': timestamp.toIso8601String(),
    };
    if (elapsed != null) {
      json['elapsedUs'] = elapsed!.inMicroseconds;
      json['elapsedMs'] = elapsed!.inMicroseconds / 1000;
    }
    if (data != null) json['data'] = data!;
    return json;
  }
}

// ─── 探针 ───

/// 轻量级调试探针 — 记录操作耗时、状态变化、错误计数。
///
/// 用法：
/// ```dart
/// final probe = DebugProbe('playback');
/// // 同步计时
/// final result = probe.measure('parse', () => parseFile(path));
/// // 异步计时
/// final data = await probe.measureAsync('fetch', () => fetchData(url));
/// // 记录事件
/// probe.record('stateChanged', {'from': 'idle', 'to': 'playing'});
/// // 导出
/// print(probe.exportJson());
/// ```
class DebugProbe {
  DebugProbe(this.name);

  final String name;
  final List<ProbeEvent> _events = [];

  /// 事件历史（只读快照）。
  List<ProbeEvent> get events => List.unmodifiable(_events);

  /// 事件计数。
  int get eventCount => _events.length;

  /// 同步计时 — 包装一个函数并记录耗时。
  T measure<T>(String label, T Function() fn) {
    if (!_probesEnabled) return fn();
    final sw = Stopwatch()..start();
    final result = fn();
    sw.stop();
    _addEvent(label, sw.elapsed);
    return result;
  }

  /// 异步计时 — 包装一个异步函数并记录耗时。
  Future<T> measureAsync<T>(String label, Future<T> Function() fn) async {
    if (!_probesEnabled) return fn();
    final sw = Stopwatch()..start();
    final result = await fn();
    sw.stop();
    _addEvent(label, sw.elapsed);
    return result;
  }

  /// 记录一个事件（无耗时）。
  void record(String label, [Map<String, Object>? data]) {
    if (!_probesEnabled) return;
    _addEvent(label, null, data);
  }

  /// 清除所有事件。
  void clear() {
    _events.clear();
  }

  /// 导出 JSON 字符串。
  String exportJson() {
    return jsonEncode({
      'name': name,
      'eventCount': _events.length,
      'events': _events.map((e) => e.toJson()).toList(),
    });
  }

  void _addEvent(String label, Duration? elapsed, [Map<String, Object>? data]) {
    _events.add(ProbeEvent(
      label: label,
      elapsed: elapsed,
      data: data,
      timestamp: DateTime.now(),
    ));
    // 限制历史长度
    if (_events.length > 1000) {
      _events.removeAt(0);
    }
  }
}

// ─── 全局注册表 ───

/// 探针注册表 — 管理所有 DebugProbe 实例。
///
/// 用法：
/// ```dart
/// final probe = DebugProbeRegistry.register('playback');
/// // ... 使用 probe ...
/// // 一键导出
/// print(DebugProbeRegistry.exportAllJson());
/// ```
class DebugProbeRegistry {
  DebugProbeRegistry._();

  static final Map<String, DebugProbe> _probes = {};

  /// 注册一个新探针（已存在则返回现有实例）。
  static DebugProbe register(String name) {
    return _probes.putIfAbsent(name, () => DebugProbe(name));
  }

  /// 查找探针。
  static DebugProbe? lookup(String name) {
    return _probes[name];
  }

  /// 所有已注册探针。
  static List<DebugProbe> get all => List.unmodifiable(_probes.values);

  /// 汇总统计 — 每个探针的名称和事件计数。
  static Map<String, Map<String, Object>> summary() {
    return {
      for (final probe in _probes.values)
        probe.name: {
          'eventCount': probe.eventCount,
          'lastEvent': probe.events.isNotEmpty
              ? probe.events.last.toJson() as Object
              : Object(),
        },
    };
  }

  /// 导出所有探针的 JSON。
  static String exportAllJson() {
    return jsonEncode({
      'probes': _probes.values.map((p) {
        final json = jsonDecode(p.exportJson()) as Map<String, dynamic>;
        return json;
      }).toList(),
      'summary': summary(),
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  /// 清除所有探针。
  static void clearAll() {
    for (final probe in _probes.values) {
      probe.clear();
    }
    _probes.clear();
  }
}
