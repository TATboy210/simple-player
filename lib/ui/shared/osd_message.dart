import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 反馈语义等级 — warning/failure share the highest admission priority.
enum OsdPriority {
  status,
  success,
  warning,
  failure;

  /// Ordering is semantic, never inferred from text or icon.
  int get rank => switch (this) {
    status => 0,
    success => 1,
    warning || failure => 2,
  };

  /// Fixed event-time lifetime, including time spent pending.
  Duration get lifetime => Duration(
    milliseconds: switch (this) {
      status => Tokens.osdDefaultHoldMs,
      success => Tokens.osdSuccessHoldMs,
      warning || failure => Tokens.osdWarningHoldMs,
    },
  );
}

/// OSD 消息数据 — immutable presentation payload; no raw diagnostic stack.
class OsdMessage {
  const OsdMessage({
    required this.text,
    this.icon,
    this.progress,
    this.priority = OsdPriority.status,
    this.coalescingKey,
  });

  /// Complete, localized SHORT summary for a non-interactive viewport bubble.
  /// Producers must keep this bounded at the minimum window/text scale; raw
  /// exceptions, arbitrary paragraphs and stacks stay in the existing card/log.
  /// This payload preserves text verbatim: no truncation, shrinking, detail store
  /// or universal fit guarantee for an unbounded String is provided here.
  final String text;
  final IconData? icon;

  /// 0.0 ~ 1.0 immediate progress; null omits the indicator.
  final double? progress;
  final OsdPriority priority;

  /// Stable event identity for warning producers; does not infer severity.
  final Object? coalescingKey;
}

/// 已入场事件 — immutable absolute monotonic deadline, never renewed on promotion.
class OsdEntry {
  const OsdEntry({
    required this.message,
    required this.admittedAt,
    required this.expiresAt,
  });

  final OsdMessage message;
  final Duration admittedAt;
  final Duration expiresAt;

  /// Equality at the deadline is expired in either callback/admission order.
  bool isValidAt(Duration now) => expiresAt > now;
}

/// 单一代际快照 — current/pending and visibility publish atomically.
class OsdSnapshot {
  const OsdSnapshot({required this.generation, this.current, this.pending});

  final int generation;
  final OsdEntry? current;
  final OsdEntry? pending;
  bool get isVisible => current != null;
}
