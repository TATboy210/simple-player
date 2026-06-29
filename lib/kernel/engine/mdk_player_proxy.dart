import 'package:fvp/mdk.dart' as mdk;

import 'player_proxy.dart';

/// Adapter that wraps mdk.Player and implements PlayerProxy.
///
/// This allows FvpEngine to pass mdk.Player to helper classes
/// that accept PlayerProxy for testability.
class MdkPlayerProxy implements PlayerProxy {
  MdkPlayerProxy(this._player);

  final mdk.Player _player;

  @override
  set volume(double value) => _player.volume = value;

  @override
  set mute(bool value) => _player.mute = value;

  @override
  void setProperty(String key, String value) =>
      _player.setProperty(key, value);

  @override
  String? getProperty(String key) => _player.getProperty(key);
}
