/// Abstract interface for player properties used by helper classes.
///
/// Defines the subset of mdk.Player API needed by VolumeController,
/// SubtitleConfigurator, and D3D11Configurator. Enables testing
/// with pure Dart fakes without FFI dependencies.
abstract class PlayerProxy {
  /// Set audio volume (0.0 - 1.0).
  set volume(double value);

  /// Set mute state.
  set mute(bool value);

  /// Set a player property by key-value pair.
  void setProperty(String key, String value);

  /// Get a player property value, or null if not set.
  String? getProperty(String key);
}
