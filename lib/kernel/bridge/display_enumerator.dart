/// 平台无关的显示器枚举抽象。
///
/// 定义 [DisplayInfo] 数据类和 [DisplayEnumerator] 接口，
/// 使 [ScreenUtils] 和 [FullscreenController] 不直接依赖 Win32 FFI。
///
/// macOS/Linux 移植只需实现此接口。
library;

import 'dart:ui';

/// 单个显示器的几何信息（平台无关）。
class DisplayInfo {
  const DisplayInfo({
    required this.bounds,
    required this.workArea,
    required this.isPrimary,
  });

  /// 完整显示器范围（含任务栏区域）。
  final Rect bounds;

  /// 工作区域（排除任务栏）。
  final Rect workArea;

  /// 是否为主显示器。
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayInfo &&
          bounds == other.bounds &&
          workArea == other.workArea &&
          isPrimary == other.isPrimary;

  @override
  int get hashCode => Object.hash(bounds, workArea, isPrimary);

  @override
  String toString() =>
      'DisplayInfo(bounds=$bounds, work=$workArea, primary=$isPrimary)';
}

/// 显示器枚举器抽象接口。
///
/// 获取连接的显示器几何信息，用于多显示器窗口钳制。
abstract class DisplayEnumerator {
  /// 获取所有连接的显示器及其几何信息。
  List<DisplayInfo> enumerateDisplays();

  /// 获取包含指定窗口句柄的显示器信息。
  DisplayInfo? getDisplayForWindow(int hwnd);

  /// 获取当前 Flutter 窗口所在显示器的信息。
  DisplayInfo? getCurrentDisplay();
}
