import 'engine_state.dart';

/// Capability marker for engines that support renderer configuration.
///
/// This mixin enables Dart 3 pattern matching for runtime capability checks
/// without unsafe casting:
///
/// ```dart
/// if (engine case RendererConfig rc) {
///   rc.setSyncEnabled(true); // safe — engine supports renderer config
/// }
/// ```
///
/// Used by UI code that needs renderer-specific features (e.g., D3D11 sync
/// toggle, hardware decoding switch). The actual methods are defined on
/// [EngineState] — this mixin exists purely for type-level pattern matching.
mixin RendererConfig on EngineState {}
