import 'engine_state.dart';

/// 渲染器配置能力标记 mixin
///
/// 用于运行时能力检查: `if (engine case RendererConfig rc) { ... }`
mixin RendererConfig on EngineState {}
