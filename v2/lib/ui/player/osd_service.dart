import 'dart:async';

/// OSD 消息
class OsdMessage {
  final String text;
  final int holdMs;

  const OsdMessage(this.text, {this.holdMs = 1200});
}

/// 全局 OSD 服务（Singleton）
///
/// 任何层都可以通过 OsdService.instance.show('text') 显示 OSD。
/// OsdOverlay 监听 [messages] 流来渲染动画。
class OsdService {
  OsdService._();
  static final instance = OsdService._();

  final _controller = StreamController<OsdMessage>.broadcast();

  /// OSD 消息流
  Stream<OsdMessage> get messages => _controller.stream;

  /// 显示 OSD 消息
  void show(String text, {int holdMs = 1200}) {
    _controller.add(OsdMessage(text, holdMs: holdMs));
  }

  void dispose() => _controller.close();
}
