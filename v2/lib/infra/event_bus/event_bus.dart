import 'dart:async';

/// 类型化事件总线 — 零外部依赖
///
/// 所有模块通过 EventBus 通信，禁止直接调用。
/// 支持任意事件类型（PlayerEvent、WindowEvent 等）。
class EventBus {
  final _controller = StreamController<Object>.broadcast();

  void fire(Object event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Stream<T> on<T>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  Stream<Object> get stream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
