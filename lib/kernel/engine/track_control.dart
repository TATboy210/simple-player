import 'engine_state.dart';

/// 音轨/字幕控制能力标记 mixin
///
/// 用于运行时能力检查: `if (engine case TrackControl tc) { ... }`
/// 方法定义保留在 EngineState 基类中，此 mixin 仅提供类型标记。
mixin TrackControl on EngineState {}
