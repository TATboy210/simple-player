import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../diagnostics/kernel_logger.dart';

// --- @Native external bindings (Dart 3.13 assetId 直连, B0 probe 5a GO) ---
// 与 ime_bridge.dart 同形态声明(刻意重复,不共享/不 import — 两个独立桥各自
// 维护本地绑定,2 行重复声明代价低于跨文件耦合)。B0 探针实测 assetId='user32'
// 无需 native-assets 注册即可解析 user32 独有函数。user32 在 Windows 恒存在。

/// user32!FindWindowW — 按类名(可选+窗口名)定位顶层窗口,找不到返回 0。
///
/// native HWND 是指针宽度,用 `IntPtr` 承载;LPCWSTR 按 UTF-16 布局以
/// `Pointer<Uint16>` 传入(Utf16 与 Uint16 同为 16 位,cast 是 FFI 惯用法)。
@Native<IntPtr Function(Pointer<Uint16>, Pointer<Uint16>)>(
  symbol: 'FindWindowW',
  assetId: 'user32',
)
external int _findWindowW(
  Pointer<Uint16> lpClassName,
  Pointer<Uint16> lpWindowName,
);

/// user32!SendMessageTimeoutW — 投递消息并等待目标线程处理(跨线程安全)。
///
/// LRESULT/UINT/WPARAM/LPARAM 分别用 `IntPtr`/`Uint32`/`UintPtr`/`UintPtr` 承载;
/// 第七参数 PDWORD_PTR 指向 handler 返回值。返回非零=投递成功。
@Native<
  IntPtr Function(
    IntPtr,
    Uint32,
    UintPtr,
    UintPtr,
    Uint32,
    Uint32,
    Pointer<UintPtr>,
  )
>(symbol: 'SendMessageTimeoutW', assetId: 'user32')
external int _sendMessageTimeoutW(
  int hwnd,
  int message,
  int wparam,
  int lparam,
  int fuFlags,
  int uTimeout,
  Pointer<UintPtr> lpdwResult,
);

/// 单次 WM_ENTERSIZEMOVE/WM_EXITSIZEMOVE 模态循环状态快照。
///
/// 由 runner 侧 sizemove_bridge_messages.h 的 HandleQuerySizemove 打包
/// （LRESULT 64 位），本类负责解码。用于 v0.0.9 P0-1 拖窗/Resize 取证：
/// 判定 Dart 侧 500ms 防抖推断与 Windows 原生拖拽 session 的偏差。
final class SizemoveSnapshot {
  const SizemoveSnapshot({
    required this.isActive,
    this.exitLagMs = 0,
    this.enterTick,
  });

  /// 查询时刻原生模态循环（用户正在拖拽/缩放窗口）是否仍在进行。
  final bool isActive;

  /// 距上次 WM_EXITSIZEMOVE 的毫秒数；仍在拖拽中时为 0。
  final int exitLagMs;

  /// 进入模态循环的时刻（GetTickCount 时钟）；null = 本次运行从未进入过。
  final int? enterTick;

  /// 解码 runner 打包布局：bit0 active | bits1-16 exitLagMs | bits17-48 enterTick。
  factory SizemoveSnapshot.decode(int raw) {
    final tick = (raw >> 17) & 0xFFFFFFFF;
    return SizemoveSnapshot(
      isActive: (raw & 1) == 1,
      exitLagMs: (raw >> 1) & 0xFFFF,
      enterTick: tick == 0 ? null : tick,
    );
  }
}

/// SIZEMOVE 模态循环查询接口 — WindowResizeCoordinator 依赖的窄接口。
///
/// 纯观测契约：实现不得改变窗口行为；查询失败返回 null（不抛异常路径
/// 由调用方兜底）。null 接线（未注入）时 coordinator 行为与旧版等价。
abstract interface class SizemoveProbe {
  SizemoveSnapshot? query();
}

/// Win32 SIZEMOVE 桥 — 经跨线程消息查询窗口拖拽-缩放模态循环状态。
///
/// 架构位置：复刻同目录 ime_bridge.dart 的 FindWindowW +
/// SendMessageTimeoutW 模式（消息常量与 windows/runner/
/// sizemove_bridge_messages.h 对偶维护）。ENTERSIZEMOVE/EXITSIZEMOVE
/// 由 runner MessageHandler 在 platform 线程记录（纯观测不消费），
/// 本桥投递 `WM_APP+0x4A` 在同一线程读回打包状态。
///
/// hwnd 定位限制与 ime_bridge 相同：FindWindowW 按类名返回首个同类名
/// 顶层窗口 — 本应用单实例使用无碍。
class Win32SizemoveBridge implements SizemoveProbe {
  /// runner 主窗口类名 — 与 win32_window.cpp 的 kWindowClassName 对齐.
  static const String _windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';

  /// 自定义消息号 — WM_APP(0x8000) + 0x4A，与 runner 侧
  /// sizemove_bridge_messages.h 的 kAppQuerySizemove 对偶（勿单边修改）.
  static const int _messageId = 0x8000 + 0x4A;

  /// SendMessageTimeoutW 的 SMTO_ABORTIFHUNG — 目标线程挂死时放弃.
  static const int _smtoAbortIfHung = 0x0002;

  /// 跨线程 Send 超时（毫秒）— 状态读取为 O(1) 内存操作，正常瞬间完成.
  static const int _sendTimeoutMs = 1000;

  final KernelLogger _log;

  /// 可注入的 FFI 函数束 — 测试用 fake 替换，生产走真实动态库.
  final Win32SizemoveFunctions _fns;

  Win32SizemoveBridge({KernelLogger? logger, Win32SizemoveFunctions? functions})
    : _log = logger ?? KernelLogger.I,
      _fns = functions ?? _resolveDefaultFunctions();

  @override
  SizemoveSnapshot? query() {
    if (!Platform.isWindows) return null;
    // 261009-fio H1：FindWindowW/SendMessageTimeoutW 的 @Native 绑定首调
    // 才解析，解析失败抛 ArgumentError（Error 族）——为兑现 SizemoveProbe
    // 契约（查询失败返回 null、绝不抛出）而兜住该环境性失败；只捕获
    // ArgumentError（绑定解析的专属签名），编程 bug 的其他 Error 仍上抛。
    try {
      final hwnd = _fns.findWindow(_windowClassName);
      if (hwnd == 0) {
        _log.warn(
          'Win32SizemoveBridge.query: runner window not found by class '
          'name, sizemove state unavailable',
        );
        return null;
      }
      // 与 ime_bridge 的差异：透传 handler 返回值而非判非零 — 打包状态
      // （active=false 且 tick=0）合法地为 0，不能当失败。
      final raw = _fns.sendMessageTimeout(
        hwnd,
        _messageId,
        0,
        _smtoAbortIfHung,
        _sendTimeoutMs,
      );
      if (raw == null) {
        _log.warn(
          'Win32SizemoveBridge.query: message delivery failed '
          '(timeout/hung), sizemove state unavailable',
        );
        return null;
      }
      return SizemoveSnapshot.decode(raw);
    } on ArgumentError catch (error, stackTrace) {
      _log.warn(
        'Win32SizemoveBridge.query: sizemove state unavailable — '
        'user32 assetId binding resolution failed',
        context: <String, Object?>{
          'error': '$error',
          'stackTrace': '$stackTrace',
        },
      );
      return null;
    }
  }

  /// 生产 FFI 函数束 — 调用顶层 @Native external 绑定(Dart 3.13 assetId 直连).
  static Win32SizemoveFunctions _resolveDefaultFunctions() {
    return Win32SizemoveFunctions(
      findWindow: (className) {
        final namePtr = className.toNativeUtf16();
        try {
          return _findWindowW(namePtr.cast<Uint16>(), nullptr);
        } finally {
          calloc.free(namePtr);
        }
      },
      sendMessageTimeout: (hwnd, message, wparam, flags, timeoutMs) {
        final result = calloc<UintPtr>();
        try {
          final sent = _sendMessageTimeoutW(
            hwnd,
            message,
            wparam,
            0,
            flags,
            timeoutMs,
            result,
          );
          // 仅投递失败（超时/挂死）返回 null；handler 返回值原样透传.
          return sent != 0 ? result.value : null;
        } finally {
          calloc.free(result);
        }
      },
    );
  }
}

/// FFI 函数束 — 抽象动态库解析，测试注入 fake 实现.
@visibleForTesting
class Win32SizemoveFunctions {
  /// 按类名定位顶层窗口（FindWindowW；找不到返回 0）。
  final int Function(String className) findWindow;

  /// 投递自定义消息并等待目标线程处理（SendMessageTimeoutW 封装）。
  ///
  /// 返回 handler 打包结果（见 [SizemoveSnapshot.decode]）；投递失败
  /// （超时/挂死/失败）返回 null。
  final int? Function(
    int hwnd,
    int message,
    int wparam,
    int flags,
    int timeoutMs,
  )
  sendMessageTimeout;

  const Win32SizemoveFunctions({
    required this.findWindow,
    required this.sendMessageTimeout,
  });
}
