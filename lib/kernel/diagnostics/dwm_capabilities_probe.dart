/// DWM 能力探测 FFI 叶子 — Phase 6 (ENAB-01, D-01)
///
/// Dart FFI leaf that probes DWM attribute availability at startup.
/// Opens ntdll (RtlGetVersion), user32 (GetShellWindow), dwmapi
/// (DwmGetWindowAttribute) and checks four Win11 22000+ attributes.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'dwm_capabilities.dart';
import 'kernel_logger.dart';

/// 日志门面 — DwmCapabilitiesProbe 共用（kernel 惯例）
final _log = KernelLogger.I;

// --- FFI: RtlGetVersion (OSVERSIONINFOW) ---

/// RTL_OSVERSIONINFOW struct layout (copy-not-link from
/// media_kit_video-2.0.1/windows/utils.cc:85 per CONTEXT canonical_refs).
/// dwBuildNumber is a ULONG (Uint32) at offset 12 — integer-exact, no
/// floating point, no overflow at realistic build numbers (< 2^32).
final class _OSVERSIONINFOW extends Struct {
  @Uint32()
  external int dwOSVersionInfoSize;
  @Uint32()
  external int dwMajorVersion;
  @Uint32()
  external int dwMinorVersion;
  @Uint32()
  external int dwBuildNumber;
  @Uint32()
  external int dwPlatformId;
  @Array(128)
  external Array<Uint16> szCSDVersion;
}

typedef _RtlGetVersionNative = Int32 Function(Pointer<_OSVERSIONINFOW>);
typedef _RtlGetVersionDart = int Function(Pointer<_OSVERSIONINFOW>);

// --- FFI: GetShellWindow ---

typedef _GetShellWindowNative = Pointer<Void> Function();
typedef _GetShellWindowDart = Pointer<Void> Function();

// --- FFI: DwmGetWindowAttribute ---

typedef _DwmGetWindowAttributeNative = Int32 Function(
  Pointer<Void> hwnd,
  Uint32 dwAttribute,
  Pointer<Void> pvAttribute,
  Uint32 cbAttribute,
);
typedef _DwmGetWindowAttributeDart = int Function(
  Pointer<Void> hwnd,
  int dwAttribute,
  Pointer<Void> pvAttribute,
  int cbAttribute,
);

/// S_OK HRESULT (0) — DwmGetWindowAttribute 成功
const int _sOk = 0;

/// DWM 属性 ID 常量（STACK.md build-floor matrix）
const int _dwmwaWindowCornerPreference = 33;
const int _dwmwaBorderColor = 34;
const int _dwmwaCaptionColor = 35;
const int _dwmwaTextColor = 36;

/// DWM 能力探测 FFI 叶子 — RtlGetVersion + DwmGetWindowAttribute
///
/// Synchronous FFI probe that detects Windows build number and DWM
/// attribute availability. Returns null on DLL-absent failure. Takes no
/// HWND parameter — acquires the shell (Progman) HWND internally via
/// [GetShellWindow] for capability detection, not the app window.
class DwmCapabilitiesProbe {
  /// 创建可注入 logger 的探测实例（测试 seam）
  ///
  /// Creates a probe instance. [logger] defaults to the file-scope
  /// [KernelLogger.I] singleton; tests may inject a fake.
  DwmCapabilitiesProbe({KernelLogger? logger}) : _logger = logger ?? _log;

  final KernelLogger _logger;

  /// 执行启动期 DWM 能力探测 — 同步 FFI，返回 null on failure
  ///
  /// Probes the Windows build number and four DWM attributes. Returns a
  /// populated [DwmCapabilitySnapshot] on success, or null if any DLL is
  /// absent or lookup fails (graceful degradation — app continues).
  DwmCapabilitySnapshot? probe() {
    try {
      final buildNumber = _readBuildNumber();
      if (buildNumber == null) return null;

      final shellHwnd = _getShellHwnd();
      if (shellHwnd == nullptr) {
        _logger.e(
          '[DwmCapabilities] GetShellWindow returned null — no shell window',
        );
        return null;
      }

      final dwmGetWindowAttribute = _lookupDwmGetWindowAttribute();

      // Probe each attribute — allocate a dummy DWORD buffer that
      // DwmGetWindowAttribute writes to (we only check the HRESULT).
      final dummy = malloc<Uint32>();
      try {
        final hrCorner = dwmGetWindowAttribute(
          shellHwnd,
          _dwmwaWindowCornerPreference,
          dummy.cast<Void>(),
          sizeOf<Uint32>(),
        );
        final hrBorder = dwmGetWindowAttribute(
          shellHwnd,
          _dwmwaBorderColor,
          dummy.cast<Void>(),
          sizeOf<Uint32>(),
        );
        final hrCaption = dwmGetWindowAttribute(
          shellHwnd,
          _dwmwaCaptionColor,
          dummy.cast<Void>(),
          sizeOf<Uint32>(),
        );
        final hrText = dwmGetWindowAttribute(
          shellHwnd,
          _dwmwaTextColor,
          dummy.cast<Void>(),
          sizeOf<Uint32>(),
        );

        return DwmCapabilitySnapshot(
          buildNumber: buildNumber,
          supportsCornerPreference: processHResult(
            hrCorner,
            _dwmwaWindowCornerPreference,
            buildNumber,
          ),
          supportsBorderColor: processHResult(
            hrBorder,
            _dwmwaBorderColor,
            buildNumber,
          ),
          supportsCaptionColor: processHResult(
            hrCaption,
            _dwmwaCaptionColor,
            buildNumber,
          ),
          supportsTextColor: processHResult(
            hrText,
            _dwmwaTextColor,
            buildNumber,
          ),
        );
      } finally {
        malloc.free(dummy);
      }
    } on Exception catch (error, stackTrace) {
      _logger.e(
        '[DwmCapabilities] FFI probe failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// 处理 DwmGetWindowAttribute 的 HRESULT — 返回属性是否可用
  ///
  /// Processes the HRESULT from a DwmGetWindowAttribute call. **任何非 S_OK
  /// 都是探测答案而非应用故障**（2026-09-06 语义软化）：能力探测是容错
  /// 查询——E_INVALIDARG（实测 Win11 26200 对 Progman 查询 COLOR 系属性）、
  /// E_NOTIMPL、DWM_E_*，乃至 Release 实机出现过的 E_FAIL 族（Progman
  /// 的 DWM 语义随桌面状态漂移），全部只意味着「该属性在当前环境不可用」，
  /// 消费方按 false 走降级路径。旧版「预期族白名单 + 意外 hr 上报错误
  /// 卡片」把探测答案当故障处理（Occurrence 3 的 E_FAIL 报告），与探测
  /// 的容错目的自相矛盾——D-04 上报语义仅适用于真实操作场景，此处统一
  /// 降为 warn 级观测日志（携带 hr/属性/build 上下文，可诊断），快照记
  /// false。返回 true 当且仅当 [hr] == S_OK (0)。
  @visibleForTesting
  bool processHResult(int hr, int attributeId, int buildNumber) {
    if (hr == _sOk) return true;
    _logger.w(
      '[DwmCapabilities] attribute $attributeId unavailable '
      'hr=0x${hr.toRadixString(16)} — probe answer, degraded',
      context: {'attribute': attributeId, 'build': buildNumber},
    );
    return false;
  }

  /// RtlGetVersion → dwBuildNumber (integer-exact, ENAB-01)
  int? _readBuildNumber() {
    final ntdll = DynamicLibrary.open('ntdll.dll');
    final rtlGetVersion = ntdll
        .lookupFunction<_RtlGetVersionNative, _RtlGetVersionDart>(
          'RtlGetVersion',
        );

    final info = malloc<_OSVERSIONINFOW>();
    try {
      info.ref.dwOSVersionInfoSize = sizeOf<_OSVERSIONINFOW>();
      final status = rtlGetVersion(info);
      if (status != 0) {
        _logger.e(
          '[DwmCapabilities] RtlGetVersion status=0x${status.toRadixString(16)}',
        );
        return null;
      }
      return info.ref.dwBuildNumber;
    } finally {
      malloc.free(info);
    }
  }

  /// GetShellWindow → shell (Progman) HWND
  Pointer<Void> _getShellHwnd() {
    final user32 = DynamicLibrary.open('user32.dll');
    final getShellWindow = user32
        .lookupFunction<_GetShellWindowNative, _GetShellWindowDart>(
          'GetShellWindow',
        );
    return getShellWindow();
  }

  /// DwmGetWindowAttribute lookup
  int Function(Pointer<Void>, int, Pointer<Void>, int)
  _lookupDwmGetWindowAttribute() {
    final dwmapi = DynamicLibrary.open('dwmapi.dll');
    return dwmapi.lookupFunction<
      _DwmGetWindowAttributeNative,
      _DwmGetWindowAttributeDart
    >('DwmGetWindowAttribute');
  }
}
