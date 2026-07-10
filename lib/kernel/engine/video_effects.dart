import 'engine_state.dart';

/// Capability marker for engines that support video effects.
///
/// Marks engines that support brightness, contrast, hue, saturation,
/// rotation, aspect ratio, and deinterlace controls. Used for runtime
/// capability checks in the settings UI:
///
/// ```dart
/// if (engine case VideoEffects ve) {
///   // Show video effects tab — engine supports them
/// }
/// ```
mixin VideoEffects on EngineState {}
