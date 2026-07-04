/// Platform-agnostic display enumeration abstraction.
///
/// Defines [DisplayInfo] data class and [DisplayEnumerator] interface
/// so that [ScreenUtils] does not directly depend on Win32 FFI.
///
/// Platform implementations:
/// - Windows: [Win32DisplayAdapter] (wraps [Win32DisplayEnumerator])
/// - macOS/Linux: implement [DisplayEnumerator] with native APIs
///
/// Used by [ScreenUtils] for multi-monitor window clamping — ensures
/// windows stay within visible display bounds when dragged across monitors.
library;

import 'dart:ui';

/// Geometry information for a single display (platform-agnostic).
///
/// All coordinates are in Flutter logical pixels (not physical pixels).
/// Platform implementations convert from native coordinates (e.g., Win32
/// physical pixels) using the device pixel ratio.
class DisplayInfo {
  const DisplayInfo({
    required this.bounds,
    required this.workArea,
    required this.isPrimary,
  });

  /// Full display area including taskbar (logical pixels).
  final Rect bounds;

  /// Usable area excluding taskbar (logical pixels).
  // bounds 含任务栏，workArea 排除任务栏 — 窗口钳制用 workArea 避免被任务栏遮挡
  final Rect workArea;

  /// Whether this is the primary (main) display.
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

/// Display enumerator abstract interface.
///
/// Provides platform-agnostic access to connected displays for multi-monitor
/// window clamping. Implementations must convert native coordinates to
/// Flutter logical pixels.
abstract class DisplayEnumerator {
  /// Enumerates all connected displays with their geometry.
  ///
  /// Used by [ScreenUtils] to determine clamp bounds when a window
  /// is dragged across monitors or snapped to screen edges.
  List<DisplayInfo> enumerateDisplays();

  /// Returns the display containing the given window handle.
  ///
  /// Used to determine "which monitor am I on" for positioning
  /// relative to the current display (e.g., centering, clamping).
  DisplayInfo? getDisplayForWindow(int hwnd);

  /// Convenience: returns the display for the current Flutter window.
  ///
  /// Equivalent to `getDisplayForWindow(flutterHwnd)` — used when
  /// the caller doesn't need to specify a custom window handle.
  DisplayInfo? getCurrentDisplay();
}
