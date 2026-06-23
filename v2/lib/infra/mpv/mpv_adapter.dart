import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../event_bus/event_bus.dart';
import '../../core/state/playback_state.dart';
import '../../core/events/player_events.dart' as events;
import 'mpv_bindings.dart';

class MpvAdapter {
  final MpvBindings _bindings;
  final EventBus _bus;
  late Pointer<Void> _handle;
  bool _initialized = false;
  Timer? _eventTimer;
  int _positionMs = 0;
  int _durationMs = 0;
  double _volume = 100.0;
  bool _muted = false;
  MpvAdapter(this._bindings, this._bus);

  Future<void> init() async {
    _handle = _bindings.mpv_create();
    if (_handle == nullptr) throw StateError('mpv_create returned null');
    debugPrint('[MpvAdapter] mpv_create OK, handle=${_handle.address}');

    _setOption('vo', 'null');
    _setOption('hwdec', 'auto');
    _setOption('ao', 'wasapi');
    _setOption('keep-open', 'yes');
    _setOption('terminal', 'no');
    _setOption('msg-level', 'all=v');

    final result = _bindings.mpv_initialize(_handle);
    if (result != MpvError.success) throw StateError('mpv_initialize failed: $result');

    _initialized = true;
    debugPrint('[MpvAdapter] mpv_initialize OK');
    _observeProperty('time-pos', 1);
    _observeProperty('duration', 2);
    _observeProperty('volume', 3);
    _observeProperty('mute', 4);
    _observeProperty('pause', 5);
    _startEventLoop();
  }

  void _setOption(String key, String value) {
    final keyPtr = key.toNativeUtf8();
    final valPtr = value.toNativeUtf8();
    try { _bindings.mpv_set_option_string(_handle, keyPtr, valPtr); }
    finally { calloc.free(keyPtr); calloc.free(valPtr); }
  }

  void _observeProperty(String name, int userData) {
    final namePtr = name.toNativeUtf8();
    try { _bindings.mpv_observe_property(_handle, userData, namePtr, 0); }
    finally { calloc.free(namePtr); }
  }

  int getPropertyInt(String name) {
    final n = name.toNativeUtf8();
    final v = calloc<Int64>();
    try { return _bindings.mpv_get_property(_handle, n, MpvFormat.int64, v.cast()) == MpvError.success ? v.value : 0; }
    finally { calloc.free(n); calloc.free(v); }
  }

  double _getPropertyDouble(String name) {
    final n = name.toNativeUtf8();
    final v = calloc<Double>();
    try { return _bindings.mpv_get_property(_handle, n, MpvFormat.double_, v.cast()) == MpvError.success ? v.value : 0.0; }
    finally { calloc.free(n); calloc.free(v); }
  }

  bool getPropertyFlag(String name) {
    final n = name.toNativeUtf8();
    final v = calloc<Int32>();
    try {
      final rc = _bindings.mpv_get_property(_handle, n, MpvFormat.flag, v.cast());
      return rc == MpvError.success ? v.value == 1 : false;
    } finally {
      calloc.free(n);
      calloc.free(v);
    }
  }

  String? getPropertyString(String name) {
    if (!_initialized) return null;
    final n = name.toNativeUtf8();
    try {
      final ptr = _bindings.mpv_get_property_string(_handle, n);
      if (ptr == nullptr) return null;
      final result = ptr.toDartString();
      _bindings.mpv_free(ptr.cast());
      return result;
    } finally { calloc.free(n); }
  }

  Future<void> command(List<String> args) async {
    if (!_initialized) return;
    final pointers = <Pointer<Utf8>>[];
    for (final arg in args) { pointers.add(arg.toNativeUtf8()); }
    pointers.add(nullptr);
    final argv = calloc<Pointer<Utf8>>(pointers.length);
    for (var i = 0; i < pointers.length; i++) { argv[i] = pointers[i]; }
    try {
      final result = _bindings.mpv_command(_handle, argv);
      if (result != MpvError.success) {
        _bus.fire(events.ErrorOccurred('mpv command failed: ${args.join(" ")} (code $result)'));
      }
    } finally {
      for (final p in pointers) { calloc.free(p); }
      calloc.free(argv);
    }
  }

  void setProperty(String name, String value) {
    if (!_initialized) return;
    final n = name.toNativeUtf8();
    final v = value.toNativeUtf8();
    try { _bindings.mpv_set_property_string(_handle, n, v); }
    finally { calloc.free(n); calloc.free(v); }
  }

  void _startEventLoop() {
    _eventTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _pollEvents());
  }

  void _pollEvents() {
    if (!_initialized) return;
    try {
      var count = 0;
      while (count < 256) {
        final eventPtr = _bindings.mpv_wait_event(_handle, 0);
        if (eventPtr == nullptr) break;
        if (eventPtr.ref.event_id == MpvEventId.none) break;
        _handleEvent(eventPtr.ref);
        count++;
      }
    } catch (e) {
      debugPrint('[MpvAdapter] _pollEvents error: $e');
    }
  }

  void _handleEvent(MpvEvent event) {
    switch (event.event_id) {
      case MpvEventId.fileLoaded:
        debugPrint('[MpvAdapter] fileLoaded event received');
        _bus.fire(events.MediaOpened(getPropertyString('path') ?? ''));
        _bus.fire(const events.StateChanged(PlaybackState.playing));
      case MpvEventId.endFile:
        _bus.fire(const events.StateChanged(PlaybackState.ended));
      case MpvEventId.pause:
        _bus.fire(const events.StateChanged(PlaybackState.paused));
      case MpvEventId.unpause:
        _bus.fire(const events.StateChanged(PlaybackState.playing));
      case MpvEventId.seek:
        _bus.fire(const events.StateChanged(PlaybackState.seeking));
      case MpvEventId.startFile:
        _bus.fire(const events.StateChanged(PlaybackState.opening));
      case MpvEventId.tracksChanged:
        _bus.fire(const events.TrackChanged('all'));
      case MpvEventId.trackSwitched:
        _bus.fire(const events.TrackChanged('switched'));
      case MpvEventId.propertyChange:
        _handlePropertyChange(event);
      case MpvEventId.shutdown:
        _initialized = false;
    }
  }

  void _handlePropertyChange(MpvEvent event) {
    switch (event.reply_userdata) {
      case 1:
        final newPos = (_getPropertyDouble('time-pos') * 1000).round();
        if (newPos != _positionMs) { _positionMs = newPos; _bus.fire(events.PositionChanged(_positionMs, _durationMs)); }
      case 2:
        _durationMs = (_getPropertyDouble('duration') * 1000).round();
        _bus.fire(events.PositionChanged(_positionMs, _durationMs));
      case 3:
        final vol = _getPropertyDouble('volume');
        if (vol != _volume) { _volume = vol; _bus.fire(events.VolumeChanged(vol)); }
      case 4:
        final muted = getPropertyInt('mute') == 1;
        if (muted != _muted) { _muted = muted; _bus.fire(events.MuteChanged(muted)); }
      case 5:
        final paused = getPropertyInt('pause') == 1;
        _bus.fire(events.StateChanged(paused ? PlaybackState.paused : PlaybackState.playing));
    }
  }

  Future<void> load(String path) async {
    debugPrint('[MpvAdapter] load: $path');
    _bus.fire(const events.StateChanged(PlaybackState.opening));
    await command(['loadfile', path]);
  }

  Future<void> play() async => setProperty('pause', 'no');
  Future<void> pause() async => setProperty('pause', 'yes');
  Future<void> togglePlayPause() async {
    setProperty('pause', getPropertyInt('pause') == 1 ? 'no' : 'yes');
  }

  Future<void> seekTo(int ms) async => command(['seek', (ms / 1000).toStringAsFixed(3), 'absolute']);
  Future<void> stop() async {
    await command(['stop']);
    _positionMs = 0; _durationMs = 0;
    _bus.fire(const events.StateChanged(PlaybackState.idle));
  }

  void setVolume(double volume) => setProperty('volume', volume.toStringAsFixed(1));
  void setMute(bool muted) => setProperty('mute', muted ? 'yes' : 'no');

  bool get isPlaying => _initialized && getPropertyInt('pause') == 0;
  bool get isPaused => _initialized && getPropertyInt('pause') == 1;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  double get volume => _volume;
  bool get muted => _muted;

  /// mpv_handle 指针地址 — 供 MpvRenderService 创建渲染上下文
  int get mpvHandleAddress => _handle.address;

  void dispose() {
    _initialized = false;
    _eventTimer?.cancel();
    _eventTimer = null;
    _bindings.mpv_terminate_destroy(_handle);
  }
}
