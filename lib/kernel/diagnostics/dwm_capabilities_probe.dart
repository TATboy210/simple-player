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

// --- FFI: GetShellWindow ---

typedef _GetShellWindowNative = Pointer<Void> Function();

// --- FFI: DwmGetWindowAttribute ---

typedef _DwmGetWindowAttributeNative = Int32 Function(
  Pointer<Void> hwnd,
  Uint32 dwAttribute,
  Pointer<Void> pvAttribute,
  Uint32 cbAttribute,
);

// --- @Native external bindings (Dart 3.13 assetId 直连, B0 probe 5a GO) ---
// 复用上方 native-side typedef 作 @Native 类型实参(B0 探针用内联类型,本文件
// 已有 typedef 故直接复用;两种形态对 native 签名等价)。原 lookupFunction 的
// Dart-side typedef 已删除。
// 【261009-fio H1 勘误 2026-10-09】旧注释声称 probe() 的 on Exception catch
// 是三个 @Native 调用的统一捕获点——不实:@Native external 绑定首调才解析,
// 解析失败(DLL/符号缺失)抛 ArgumentError,属 Error 族,on Exception 捕获
// 不到,probe() 的 null 降级契约由此被穿透。现 probe() 设双捕获点:
// on Exception(FFI 调用期异常)+ on ArgumentError(绑定解析失败),恢复
// lookupFunction 时代的解析失败 null 降级语义。

/// ntdll!RtlGetVersion — 读取 OSVERSIONINFOW.dwBuildNumber。
///
/// 注意:assetId 'ntdll' 在 B0 探针中**未实测**(探针只验证了 user32)。
/// 若 UAT 实机探测失败,按 5c 兜底回退本函数为
/// `DynamicLibrary.open('ntdll.dll')` + `lookupFunction`(混合模式合法且优先于
/// 强制单一模式)——作为后续 quick task 实施,勿在此处预判。
@Native<_RtlGetVersionNative>(symbol: 'RtlGetVersion', assetId: 'ntdll')
external int _rtlGetVersion(Pointer<_OSVERSIONINFOW> info);

/// user32!GetShellWindow — 返回 shell(Progman) 顶层窗口 HWND。
///
/// B0 探针已验证 assetId 'user32' 解析 user32 独有函数成功。
@Native<_GetShellWindowNative>(symbol: 'GetShellWindow', assetId: 'user32')
external Pointer<Void> _getShellWindow();

/// dwmapi!DwmGetWindowAttribute — 查询窗口的 DWM 属性值。
///
/// 注意:assetId 'dwmapi' 在 B0 探针中**未实测**(探针只验证了 user32)。
/// 若 UAT 实机探测失败,按 5c 兜底回退本函数为
/// `DynamicLibrary.open('dwmapi.dll')` + `lookupFunction`(混合模式合法且优先于
/// 强制单一模式)——作为后续 quick task 实施,勿在此处预判。
@Native<_DwmGetWindowAttributeNative>(
  symbol: 'DwmGetWindowAttribute',
  assetId: 'dwmapi',
)
external int _dwmGetWindowAttribute(
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

/// 探测绑定调用点束 — @Native 绑定的可注入 seam（261009-fio H1）。
///
/// Bundles the three @Native call points as function fields so tests can
/// inject hand-written fakes without touching real DLL resolution
/// (fakes-over-mocks house rule). [DwmProbeBindings.defaults] wires the
/// real top-level external bindings — resolution stays lazy until first
/// invocation, so merely constructing defaults never triggers FFI.
@visibleForTesting
class DwmProbeBindings {
  /// RtlGetVersion → dwBuildNumber；读取失败（status≠0）返回 null。
  final int? Function() readBuildNumber;

  /// GetShellWindow → shell (Progman) 顶层窗口 HWND（找不到返回 nullptr）。
  final Pointer<Void> Function() getShellWindow;

  /// DwmGetWindowAttribute → HRESULT（S_OK=0 表示可用）。
  final int Function(Pointer<Void>, int, Pointer<Void>, int)
  dwmGetWindowAttribute;

  /// 创建注入束 — 测试用 fake；生产走 [DwmProbeBindings.defaults]。
  const DwmProbeBindings({
    required this.readBuildNumber,
    required this.getShellWindow,
    required this.dwmGetWindowAttribute,
  });

  /// 生产绑定束 — 直连三个顶层 @Native external 绑定。
  ///
  /// readBuildNumber 的 malloc/status 语义自原 `_readBuildNumber()` 原样
  /// 迁入（sizeOf 初始化 → status≠0 记 error 返 null → finally 释放）；
  /// status≠0 的日志走文件级 `_log` 单例——生产路径实例 logger 即同一
  /// 单例，行为等价（注入 logger 只与注入 fake 束配对出现于测试）。
  /// 闭包体只在调用时才解析 @Native 绑定——构造本 factory 本身零 FFI。
  factory DwmProbeBindings.defaults() {
    return DwmProbeBindings(
      readBuildNumber: () {
        final info = malloc<_OSVERSIONINFOW>();
        try {
          info.ref.dwOSVersionInfoSize = sizeOf<_OSVERSIONINFOW>();
          final status = _rtlGetVersion(info);
          if (status != 0) {
            _log.e(
              '[DwmCapabilities] RtlGetVersion '
              'status=0x${status.toRadixString(16)}',
            );
            return null;
          }
          return info.ref.dwBuildNumber;
        } finally {
          malloc.free(info);
        }
      },
      getShellWindow: _getShellWindow,
      dwmGetWindowAttribute: _dwmGetWindowAttribute,
    );
  }
}

/// DWM 能力探测 FFI 叶子 — RtlGetVersion + DwmGetWindowAttribute
///
/// Synchronous FFI probe that detects Windows build number and DWM
/// attribute availability. Returns null on DLL-absent failure. Takes no
/// HWND parameter — acquires the shell (Progman) HWND internally via
/// [GetShellWindow] for capability detection, not the app window.
class DwmCapabilitiesProbe {
  /// 创建可注入 logger/绑定束的探测实例（测试 seam）
  ///
  /// Creates a probe instance. [logger] defaults to the file-scope
  /// [KernelLogger.I] singleton; tests may inject a fake. [bindings]
  /// defaults to the real @Native tear-offs ([DwmProbeBindings.defaults]);
  /// tests inject fake bundles so no DLL resolution ever happens.
  DwmCapabilitiesProbe({
    KernelLogger? logger,
    @visibleForTesting DwmProbeBindings? bindings,
  }) : _logger = logger ?? _log,
       _bindings = bindings ?? DwmProbeBindings.defaults();

  final KernelLogger _logger;

  /// 绑定调用点束 — 生产为真实 @Native tear-off，测试注入 fake。
  final DwmProbeBindings _bindings;

  /// 执行启动期 DWM 能力探测 — 同步 FFI，返回 null on failure
  ///
  /// Probes the Windows build number and four DWM attributes. Returns a
  /// populated [DwmCapabilitySnapshot] on success, or null if any DLL is
  /// absent or lookup fails (graceful degradation — app continues).
  ///
  /// 261009-fio H1：双捕获点恢复 lookupFunction 时代的 null 降级语义 —
  /// on Exception 兜 FFI 调用期异常，on ArgumentError 兜 @Native 绑定
  /// 首调解析失败（Error 族，on Exception 捕不到）。仅捕 ArgumentError
  /// 这一种 Error（绑定解析的专属签名），其余 Error 是编程 bug 仍上抛。
  DwmCapabilitySnapshot? probe() {
    try {
      final buildNumber = _bindings.readBuildNumber();
      if (buildNumber == null) return null;

      final shellHwnd = _bindings.getShellWindow();
      if (shellHwnd == nullptr) {
        _logger.e(
          '[DwmCapabilities] GetShellWindow returned null — no shell window',
        );
        return null;
      }

      final dwmGetWindowAttribute = _bindings.dwmGetWindowAttribute;

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
    } on ArgumentError catch (error, stackTrace) {
      // @Native assetId 绑定首调解析失败（DLL/符号缺失）— 环境性失败而非
      // 编程 bug，error 级落盘（可作系统 DLL 劫持的观测线索）后降级 null，
      // 快照保持「能力未知」，消费方按既有契约跳过属性调用。
      _logger.e(
        '[DwmCapabilities] FFI binding resolution failed (ArgumentError) '
        '— degraded to null: $error',
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
}
