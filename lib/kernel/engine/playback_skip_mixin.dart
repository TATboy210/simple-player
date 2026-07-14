import 'package:flutter/foundation.dart';

import 'engine_constants.dart';
import 'playback_control.dart';

/// 便捷跳转 mixin — 提供 skipForward/skipBack 默认实现
///
/// 混入 [PlaybackControl] 的实现类即可获得跳转能力，
/// 无需重复编写 clamp 逻辑。
///
/// 依赖（需由混入类提供）:
/// - [position] 当前播放位置（毫秒）
/// - [duration] 媒体总时长（毫秒）
/// - [seekTo] 跳转到指定位置
///
/// 注意: setRange 保留在 FvpEngine 中，因为它需要
/// _player.setRange + _guardedAction，mixin 无法访问这些依赖。
mixin PlaybackSkipMixin implements PlaybackControl {
  /// 当前播放位置（毫秒） — 由混入类提供
  ValueNotifier<int> get position;

  /// 媒体总时长（毫秒） — 由混入类提供
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
