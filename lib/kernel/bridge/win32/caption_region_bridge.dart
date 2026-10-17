/// 标题栏原生拖动区桥 — 把自绘标题栏可拖区告知 Windows runner.
///
/// Why (nativeapi 0.5.2 migration): emulating the caption with Flutter
/// gestures (pan → `startDragging`, double-tap → setMode) loses native
/// behaviour — the drag only starts after the pan slop, the double click goes
/// through Flutter's 300ms/slop double-tap arena instead of the system
/// setting, and there is no right-click system menu. The runner instead
/// answers `HTCAPTION` from `WM_NCHITTEST` over the rectangle stored here
/// (windows/runner/caption_region.h), so DefWindowProc performs drag,
/// double-click maximize/restore, drag-out-of-maximized, Aero Snap and the
/// system menu natively.
///
/// Encoding (must match caption_region.h): physical client pixels packed as
/// `left | top << 16 | right << 32 | bottom << 48`, 16 bits each, stored in a
/// window property (pointer-sized; the app ships x64/arm64 only). Removing the
/// property disables the region. 签名逐一核对 Windows SDK `WinUser.h`.
library;

import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

/// runner 侧同名属性 (windows/runner/caption_region.h kCaptionRectProperty).
const String _captionRectProperty = 'SimplePlayerCaptionRect';

/// 单个坐标分量的打包上限 (16 位无符号).
const int _maxComponent = 0xFFFF;

@Native<Int32 Function(IntPtr, Pointer<Uint16>, IntPtr)>(
  symbol: 'SetPropW',
  assetId: 'user32',
)
external int _setPropW(int hwnd, Pointer<Uint16> name, int data);

@Native<IntPtr Function(IntPtr, Pointer<Uint16>)>(
  symbol: 'RemovePropW',
  assetId: 'user32',
)
external int _removePropW(int hwnd, Pointer<Uint16> name);

/// 把物理像素矩形打包为 runner 解读的属性值; 空/越界矩形返回 0 (= 无拖动区).
///
/// 坐标先取整 (left/top 向下, right/bottom 向上, 覆盖整像素) 再夹到
/// [0, 0xFFFF]; 夹取后为空的矩形同样返回 0。
int packCaptionRect(Rect? physical) {
  if (physical == null || physical.isEmpty || !physical.isFinite) return 0;
  int clamp(double value) => value.clamp(0, _maxComponent).toInt();
  final left = clamp(physical.left.floorToDouble());
  final top = clamp(physical.top.floorToDouble());
  final right = clamp(physical.right.ceilToDouble());
  final bottom = clamp(physical.bottom.ceilToDouble());
  if (right <= left || bottom <= top) return 0;
  return left | (top << 16) | (right << 32) | (bottom << 48);
}

/// 写入/清除 [hwnd] 的标题栏拖动区 (仅 Windows 调用, 调用方负责平台门控)。
///
/// side effect: 写/删窗口属性 (随窗口销毁自动释放)。返回是否成功。
bool setRunnerCaptionRect(int hwnd, Rect? physical) => using((arena) {
  final name = _captionRectProperty
      .toNativeUtf16(allocator: arena)
      .cast<Uint16>();
  final packed = packCaptionRect(physical);
  if (packed == 0) {
    _removePropW(hwnd, name);
    return true;
  }
  return _setPropW(hwnd, name, packed) != 0;
});
