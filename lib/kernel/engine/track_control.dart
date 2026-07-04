import 'engine_state.dart';

/// Capability marker for engines that support track switching.
///
/// This mixin enables runtime capability checks via Dart 3 pattern matching:
///
/// ```dart
/// if (engine case TrackControl tc) {
///   tc.switchAudioTrack(1); // safe — engine supports track switching
/// }
/// ```
///
/// The actual track methods (switchAudioTrack, switchSubtitleTrack,
/// toggleSubtitle) are defined on [EngineState] because all FvpEngine
/// instances support track control. This marker exists to enable future
/// MockEngine implementations to omit track support in tests.
mixin TrackControl on EngineState {}
