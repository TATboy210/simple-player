/// 引擎事件 — 结构化日志记录
///
/// 每次引擎操作（open/play/seek/error）生成一个事件，
/// 保留最近 100 条，不持久化，仅用于调试和性能分析。
class EngineEvent {
  const EngineEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });

  /// 事件类型（如 'open', 'play', 'pause', 'seek', 'error'）
  final String type;

  /// 事件发生时间
  final DateTime timestamp;

  /// 附加数据（可选，如 seek 目标位置、错误消息）
  final Map<String, Object?>? data;

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
/// 设计为轻量级：无锁、无持久化、固定内存占用。
/// 容量 100 条 ≈ 正常播放 2-3 分钟的操作量。
class EngineEventLog {
  /// 默认环形缓冲容量
  static const defaultCapacity = 100;

  /// 缓冲容量
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
  int get length => _count;

  /// 是否为空
  bool get isEmpty => _count == 0;

  /// 是否已满（新条目将覆盖最旧）
  bool get isFull => _count == capacity;

  /// 添加事件
  ///
  /// 当缓冲已满时，覆盖最旧的条目（环形写入）。
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
  void clear() {
    for (var i = 0; i < capacity; i++) {
      _buffer[i] = null;
    }
    _writeIndex = 0;
    _count = 0;
  }

  /// 导出为 JSON 列表（供调试导出）
  List<Map<String, Object?>> toJson() =>
      entries.map((e) => e.toJson()).toList();
}
