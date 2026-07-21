/// 引擎事件 — 结构化日志记录
///
/// A structured event emitted by the engine on each operation
/// (open / play / pause / seek / error). Retains the most recent
/// 100 entries; not persisted — for debugging and perf analysis only.
class EngineEvent {
  /// 创建引擎事件
  ///
  /// Creates an engine event with the given [type], [timestamp], and
  /// optional [data] payload.
  const EngineEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });

  /// 事件类型（如 'open', 'play', 'pause', 'seek', 'error'）
  ///
  /// Event type identifier, e.g. `'open'`, `'play'`, `'seek'`, `'error'`.
  final String type;

  /// 事件发生时间
  ///
  /// Wall-clock timestamp when the event occurred.
  final DateTime timestamp;

  /// 附加数据（可选，如 seek 目标位置、错误消息）
  ///
  /// Optional payload map (e.g. seek target position, error message).
  final Map<String, Object?>? data;

  /// 导出为 JSON Map
  ///
  /// Returns a JSON-serialisable representation of this event.
  Map<String, Object?> toJson() => {
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    if (data != null) 'data': data,
  };

  @override
  String toString() => 'EngineEvent($type, $timestamp)';
}

/// 引擎事件环形缓冲 — 固定容量，超出覆盖最旧条目
///
/// Fixed-capacity ring buffer for engine events.
/// Lightweight: no locks, no persistence, constant memory footprint.
/// Default capacity 100 ≈ 2–3 minutes of normal playback operations.
class EngineEventLog {
  /// 默认环形缓冲容量
  ///
  /// Default ring buffer capacity (100 entries).
  static const defaultCapacity = 100;

  /// 缓冲容量
  ///
  /// Maximum number of events retained before oldest are overwritten.
  final int capacity;

  /// 底层存储
  final List<EngineEvent?> _buffer;

  /// 写入指针（下一个写入位置）
  int _writeIndex = 0;

  /// 当前条目数（不超过 capacity）
  int _count = 0;

  EngineEventLog({this.capacity = defaultCapacity})
      : _buffer = List<EngineEvent?>.filled(defaultCapacity, null);

  /// 当前条目数
  ///
  /// Number of events currently in the buffer (never exceeds [capacity]).
  int get length => _count;

  /// 是否为空
  ///
  /// Whether the buffer contains zero events.
  bool get isEmpty => _count == 0;

  /// 是否已满（新条目将覆盖最旧）
  ///
  /// Whether the buffer has reached [capacity]; next [add] overwrites the oldest.
  bool get isFull => _count == capacity;

  /// 添加事件
  ///
  /// Appends an event to the ring buffer.
  /// When full, overwrites the oldest entry (circular write).
  /// - [type]: event identifier (e.g. `'open'`, `'seek'`).
  /// - [data]: optional payload map.
  void add(String type, [Map<String, Object?>? data]) {
    final event = EngineEvent(
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );
    _buffer[_writeIndex] = event;
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_count < capacity) _count++;
  }

  /// 获取所有条目（按时间从旧到新排列）
  ///
  /// Returns all events ordered oldest-first.
  /// The list is unmodifiable.
  List<EngineEvent> get entries {
    if (_count == 0) return const [];
    if (_count < capacity) {
      return List.unmodifiable(_buffer.sublist(0, _count));
    }
    // 已满：从 _writeIndex（最旧）开始
    final result = <EngineEvent>[
      ..._buffer.sublist(_writeIndex).whereType<EngineEvent>(),
      ..._buffer.sublist(0, _writeIndex).whereType<EngineEvent>(),
    ];
    return List.unmodifiable(result);
  }

  /// 清空所有条目
  ///
  /// Removes all events and resets the write pointer.
  void clear() {
    for (var i = 0; i < capacity; i++) {
      _buffer[i] = null;
    }
    _writeIndex = 0;
    _count = 0;
  }

  /// 导出为 JSON 列表（供调试导出）
  ///
  /// Returns all events as a JSON-serialisable list (oldest first).
  List<Map<String, Object?>> toJson() =>
      entries.map((e) => e.toJson()).toList();
}
