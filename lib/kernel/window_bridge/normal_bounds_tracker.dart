import 'dart:async';
import 'dart:ui';

import 'native_window.dart';
import 'window_geometry.dart';

/// 采样冷却期 — 拖拽 resize/move 时原生事件逐帧到达，窗口属性读取是同步 FFI，
/// 不能逐事件读。冷却期内的事件只置脏，到期补一次尾沿采样。
const Duration _sampleCooldown = Duration(milliseconds: 120);

/// 「最近一次普通窗口矩形」跟踪器 — 落盘的唯一几何来源。
///
/// 采样策略为「首沿立即 + 冷却期尾沿合并」：
/// * 首个事件立刻采样 — 最大化/最小化紧随其后时，还原尺寸已被记下
///   （最大化时原生先发 resize 再发 maximized，bounds 此刻已是工作区）；
/// * 冷却期内的后续事件只置脏，到期补一次，把逐帧 3 次同步 FFI 读取
///   （isMaximized/isMinimized/bounds）降到约每 120ms 一次。
///
/// 已知取舍：
/// * Aero Snap 半屏时 isMaximized 为 false，贴边矩形会被当作还原尺寸
///   （读 WINDOWPLACEMENT 的 rcNormal 才能区分，原生 API 未暴露）；
/// * 冷却期内（≤120ms）发生的最后几个 resize 只置脏——若拖拽刚结束就立刻
///   最大化（如拖到屏幕顶部），到期采样会因 isMaximized 被跳过，还原矩形
///   停留在冷却期内最后一次实际采样值，最多滞后约一个冷却期。
class NormalBoundsTracker {
  /// [window] 取当前绑定的原生窗口（未绑定为 null）；[canTrack] 返回当前
  /// 是否允许采样（未亮窗/全屏期间为 false）。
  NormalBoundsTracker({required this.window, required this.canTrack});

  /// 取当前绑定的原生窗口。
  final NativeWindow? Function() window;

  /// 当前是否允许采样。
  final bool Function() canTrack;

  Timer? _cooldown;
  bool _dirty = false;

  /// 最近一次普通窗口（非最大化/全屏/最小化）矩形。
  Rect value = Offset.zero & defaultWindowSize;

  /// 窗口几何发生变化（resize/move 事件）— 节流后采样。
  /// Side effect：首沿同步读取原生窗口属性并启动冷却 Timer。
  void noteChanged() {
    if (_cooldown?.isActive ?? false) {
      _dirty = true;
      return;
    }
    sample();
    _cooldown = Timer(_sampleCooldown, () {
      if (!_dirty) return;
      _dirty = false;
      sample();
    });
  }

  /// 立即采样一次。最大化/最小化/全屏时跳过，否则会把工作区或屏外坐标
  /// （-32000）当成还原尺寸。
  void sample() {
    final native = window();
    if (native == null || !canTrack()) return;
    if (native.isMaximized || native.isMinimized) return;
    final bounds = native.bounds;
    // 原生读取失败时返回全零矩形 — 不能当作还原尺寸。
    if (bounds.isEmpty) return;
    value = bounds;
  }

  /// 取消冷却 Timer；重复调用安全。
  void dispose() {
    _cooldown?.cancel();
    _cooldown = null;
  }
}
