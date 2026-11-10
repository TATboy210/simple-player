import 'package:flutter/widgets.dart';

import '../../kernel/window_bridge/port/window_resize_edge.dart';
import '../../kernel/window_bridge/window_bridge.dart';

/// frameless 窗口的边缘 resize 热区（不可见交互层，CONTRACT.md D7）。
///
/// 仅 [WindowBridge.needsResizeHotZones] 为真时挂载（Linux frameless 无
/// 系统 resize 边缘）；Windows（sizing frame 保留）/macOS（hidden 保留
/// frame）有系统边缘，本组件不上树。
///
/// 命中区域 = 6px 边带 + 14px 四角，置于内容 Stack 最上层：窗口边缘地带
/// 本就无内容交互，接管指针事件等价于系统 sizing frame 的行为。指针按下
/// 即进入系统 resize 循环（startResizing），拖动过程由系统/compositor
/// 接管 — 与 Windows 边缘拖拽同一交互模型，不产生逐帧 Dart 回调。
class ResizeHotZones extends StatelessWidget {
  const ResizeHotZones({required this.windowService, super.key});

  final WindowBridge windowService;

  /// 边带宽 — 交互命中区常量（非视觉 token）。
  static const double edgeWidth = 6;

  /// 角区边长 — 对角命中优先于边带（角块在边带之后声明，命中测试先于边带）。
  static const double cornerSize = 14;

  static const List<WindowResizeEdge> _edges = WindowResizeEdge.values;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // 先边带后四角 — Stack 命中测试自上而下，角块覆盖边带端点。
        for (final edge in _edges)
          _positioned(edge, Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => windowService.startResizing(edge),
            child: const SizedBox.expand(),
          )),
      ],
    );
  }

  /// 八分区几何 — 角贴角固定见方；边带贴边、两端让出角区。
  static Positioned _positioned(WindowResizeEdge edge, Widget child) {
    return switch (edge) {
      WindowResizeEdge.topLeft => Positioned(
        left: 0, top: 0, width: cornerSize, height: cornerSize, child: child,
      ),
      WindowResizeEdge.top => Positioned(
        left: cornerSize, right: cornerSize, top: 0, height: edgeWidth,
        child: child,
      ),
      WindowResizeEdge.topRight => Positioned(
        right: 0, top: 0, width: cornerSize, height: cornerSize, child: child,
      ),
      WindowResizeEdge.left => Positioned(
        left: 0, top: cornerSize, bottom: cornerSize, width: edgeWidth,
        child: child,
      ),
      WindowResizeEdge.right => Positioned(
        right: 0, top: cornerSize, bottom: cornerSize, width: edgeWidth,
        child: child,
      ),
      WindowResizeEdge.bottomLeft => Positioned(
        left: 0, bottom: 0, width: cornerSize, height: cornerSize, child: child,
      ),
      WindowResizeEdge.bottom => Positioned(
        left: cornerSize, right: cornerSize, bottom: 0, height: edgeWidth,
        child: child,
      ),
      WindowResizeEdge.bottomRight => Positioned(
        right: 0, bottom: 0, width: cornerSize, height: cornerSize,
        child: child,
      ),
    };
  }
}
