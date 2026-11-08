import 'dart:ui';

/// 窗口默认外框尺寸 — 首次启动或持久化数据损坏时的稳定几何。
const defaultWindowSize = Size(1280, 720);

/// 窗口最小外框尺寸（原生 WM_GETMINMAXINFO 与落盘校验共用）。
const minimumWindowSize = Size(854, 480);

/// 窗口至少要有这么大一块落在某个工作区内，才算「用户还够得着标题栏」。
///
/// 宽 100px 足以抓住标题栏拖回来；高 32px 即一条标题栏（Tokens.titleBarHeight）。
const Size minimumReachableArea = Size(100, 32);

/// 持久化几何的恢复矩形；位置缺失或不可达（见 [isReachableOnAnyDisplay]）时
/// 返回 null，调用方应只应用尺寸并居中。
Rect? restoreBounds({
  required Offset? position,
  required Size size,
  required List<Rect> workAreas,
}) {
  if (position == null) return null;
  final rect = position & size;
  return isReachableOnAnyDisplay(rect, workAreas) ? rect : null;
}

/// [bounds] 是否在任一显示器工作区内留有可抓取区域。
///
/// 持久化的位置可能来自已拔掉的副屏 — 此时窗口会出现在屏幕外且无法找回。
/// [workAreas] 为空表示拿不到显示器信息，信任持久化值（宁可保持原行为，
/// 也不把窗口无故挪走）。
bool isReachableOnAnyDisplay(Rect bounds, List<Rect> workAreas) {
  if (workAreas.isEmpty) return true;
  return workAreas.any((area) {
    final visible = bounds.intersect(area);
    return visible.width >= minimumReachableArea.width &&
        visible.height >= minimumReachableArea.height;
  });
}
