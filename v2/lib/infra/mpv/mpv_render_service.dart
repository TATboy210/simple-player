import 'dart:async';
import 'package:flutter/foundation.dart';
import '../event_bus/event_bus.dart';
import '../../core/events/player_events.dart';
import '../../core/events/window_events.dart';
import 'mpv_adapter.dart';
import 'mpv_render_bridge.dart';

/// mpv 渲染服务 — 管理渲染生命周期
///
/// 订阅 EventBus 的 MediaOpened 和 WindowSizeChanged，
/// 驱动 MpvRenderBridge 创建/销毁/resize，
/// 通过 textureId 向 UI 暴露纹理 ID。
class MpvRenderService {
  MpvRenderService(this._bus, this._adapter);
  final EventBus _bus;
  final MpvAdapter _adapter;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  MpvRenderBridge? _bridge;
  final textureId = ValueNotifier<int?>(null);

  /// 已销毁标志 — 防止 dispose 后的异步回调继续执行
  bool _disposed = false;

  /// 代际计数器 — 让旧请求自动失效，解决并发竞态
  int _generation = 0;

  static const _kDefaultWidth = 1920;
  static const _kDefaultHeight = 1080;

  void init() {
    _subscriptions.add(_bus.on<MediaOpened>().listen(_onFileLoaded));
    _subscriptions.add(_bus.on<WindowSizeChanged>().listen(_onResize));
  }

  Future<void> _onFileLoaded(MediaOpened event) async {
    debugPrint('[MpvRenderService] MediaOpened received: ${event.path}');
    if (_disposed) return;
    await _createRenderContext();
  }

  Future<void> _onResize(WindowSizeChanged event) async {
    if (_disposed) return;
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      await bridge.resize(
        event.size.width.round(),
        event.size.height.round(),
      );
    } on Exception catch (e) {
      debugPrint('[MpvRenderService] resize failed: $e');
    }
  }

  Future<void> _createRenderContext() async {
    final gen = ++_generation;
    debugPrint('[MpvRenderService] _createRenderContext start, gen=$gen');
    try {
      if (_bridge != null) {
        await _bridge!.dispose();
      }
      _bridge = MpvRenderBridge();
      final w = _adapter.getPropertyInt('width');
      final h = _adapter.getPropertyInt('height');
      debugPrint('[MpvRenderService] video size: ${w}x$h, mpvHandle=${_adapter.mpvHandleAddress}');
      final id = await _bridge!.createRender(
        _adapter.mpvHandleAddress,
        w > 0 ? w : _kDefaultWidth,
        h > 0 ? h : _kDefaultHeight,
      );
      debugPrint('[MpvRenderService] createRender returned textureId=$id');
      if (gen != _generation || _disposed) return;
      textureId.value = id;
      _bus.fire(TextureCreated(id, w, h));
    } catch (e, stack) {
      debugPrint('[MpvRenderService] _createRenderContext failed: $e\n$stack');
      if (gen != _generation || _disposed) return;
      _bus.fire(ErrorOccurred('Render context failed: $e', e.toString()));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++; // 让所有进行中的 _createRenderContext 失效
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    try {
      if (_bridge != null) {
        await _bridge!.dispose();
        _bridge = null;
      }
    } catch (e) {
      debugPrint('[MpvRenderService] bridge dispose failed: $e');
    }
    textureId.value = null;
    textureId.dispose();
  }
}
