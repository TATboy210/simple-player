import 'package:flutter/foundation.dart';

import 'engine_constants.dart';
import 'playback_control.dart';

/// 便捷跳转 mixin — 提供 skipForward/skipBack 默认实现.
///
/// Skip mixin — provides default [skipForward]/[skipBack] implementations.
///
/// Mix into any [PlaybackControl] implementor to gain skip capability
/// without repeating clamp logic.
///
/// Dependencies (must be provided by the mixing class):
/// - [position] — current playback position (ms)
/// - [duration] — total media duration (ms)
/// - [seekTo] — seek to specified position
mixin PlaybackSkipMixin implements PlaybackControl {
  /// 当前播放位置（毫秒） — 由混入类提供.
  ///
  /// Current playback position (ms) — provided by mixing class.
  ValueNotifier<int> get position;

  /// 媒体总时长（毫秒） — 由混入类提供.
  ///
  /// Total media duration (ms) — provided by mixing class.
  ValueNotifier<int> get duration;

  @override
  void skipForward([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value - ms).clamp(0, duration.value));
  }
}
