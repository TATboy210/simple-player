import 'dart:async' show Completer;
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../kernel/bridge/win32/ime_bridge.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../kernel/services/path_validator.dart';
import 'file_picker_coordinator.dart';

const _filePickerAttentionChannel = MethodChannel(
  'com.simple_player/file_picker_attention',
);

/// 基于 file_picker 的媒体路径选择器。
///
/// 扩展名仍来自 [PathValidator]；picker 仅做 UI 层过滤，后续播放链路仍保留
/// 原有路径校验责任。Windows 使用 `lockParentWindow` 保持对话框模态前置。
class FilePickerMediaGateway implements FilePickerGateway {
  const FilePickerMediaGateway();

  @override
  Future<List<String>?> pickMediaPaths() async {
    // Windows 默认走 runner 主线程直调对话框（SIMPLER_PLAYER_FILE_DIALOG=
    // legacy 回退 file_picker 路径）：windows_file_picker 2.0.2 把
    // IFileOpenDialog 放进 compute 辅助 isolate，每次点击都要付出新线程
    // CoInitializeEx STA + FFI 重解析 + shell 冷启动（点击→对话框实测
    // 6~10s）；runner 主线程 STA 已预热，同款对话框 149ms 基线。
    if (Platform.isWindows && RunnerFileDialog._useNative) {
      final result = await Win32ImeBridge.withImeRestored(
        () {
              return RunnerFileDialog.show(
          extensionSpec: PathValidator.supportedExtensions.join(';'),
          lockParentWindow: true,
        ); },
      );
      if (result != RunnerFileDialog.fallback) {
        // 用户取消为 null（gateway 契约的取消，与 file_picker 路径一致）。
        return result == null ? null : <String>[result];
      }
      // runner 符号缺失（旧构建产物）→ 落穿到下方 file_picker 路径。
    }
    // 对话框期间临时恢复 IME — 窗口 IMC 已解除 (flutter_window.cpp),
    // 原生文件对话框在 NULL IMC 下触发 msctf 空指针崩溃 (v0.0.8 闪退).
    final result = await Win32ImeBridge.withImeRestored(
      // file_picker 13：pickFiles 变为多选 (返回 List)；11.x 默认单选，
      // 保持原语义改用 pickFile (单个 PlatformFile?)。
      () => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: PathValidator.supportedExtensions,
        // file_picker 12+：lockParentWindow 迁入平台 options，保持对话框
        // 模态前置于 runner 窗口（Windows/Linux 各一份）。
        windowsOptions: const WindowsOptions(lockParentWindow: true),
        linuxOptions: const LinuxOptions(lockParentWindow: true),
      ),
    );
    // 用户取消为 null——即 gateway 契约的取消，上游 coordinator 语义不变；
    // 无本地路径 (非桌面平台) 时返回空列表，与 11.x 的 whereType 过滤一致。
    if (result == null) return null;
    final path = result.path;
    return path == null ? const <String>[] : [path];
  }
}

/// 通过原生 channel 请求现有文件选择器获得 attention。
///
/// 各平台均将结果视为 best-effort：Windows 尝试激活 Common Dialog 并响铃，
/// macOS 定位 attached `NSOpenPanel`，Linux 仅播放 GTK 系统 bell。
class MethodChannelFilePickerAttention implements FilePickerAttention {
  const MethodChannelFilePickerAttention();

  @override
  Future<void> requestAttention() async {
    await _filePickerAttentionChannel.invokeMethod<void>('focusExistingPicker');
  }
}

/// runner 原生对话框通道（性能修复，A.2 异步版）。
///
/// `SimplerPlayerShowOpenDialogAsync`（windows/runner/flutter_window.cpp）
/// 在**独立 STA 线程**跑 IFileOpenDialog 并立即返回 —— UI isolate 不被
/// 阻塞（A.1 同步版的 Show() 模态循环把 UI isolate 冻结在 FFI 里整个
/// 对话框存活期：ESC 失效、点击积压"关了又弹"）。避开 windows_file_picker
/// 的 compute-isolate 冷 COM（点击→对话框 6~10s）。
///
/// 结果经 `NativeCallable.listener` 回投（任意线程可调）：runner 的
/// `DialogResultFn(request_id, code, path)` —— path 由 C++ `new wchar_t[]`
/// 分配，Dart 读取后调 `SimplerPlayerFreeString` 释放（与 `delete[]` 配对）。
///
/// IME：enable 在触发前同步执行，disable 在结果回调后 —— 异步时序下
/// 对话框整个存活期 IMC 在位（v0.0.8 msctf 崩溃防御保持）。
///
/// 返回码协议（runner 侧）：1=选中（path 含完整路径）、0=取消、
/// -1=参数错误、其他负数=HRESULT。
/// 符号缺失（旧 runner 产物）→ 返回 [fallback] 触发调用方降级。
/// runner 结果回调签名（NativeCallable.listener 持有）。
typedef DialogResultNativeFn = ffi.Void Function(
    ffi.Int32, ffi.Int32, ffi.Pointer<ffi.Uint16>);
typedef DialogResultDartFn = void Function(int, int, ffi.Pointer<ffi.Uint16>);

abstract final class RunnerFileDialog {
  /// pickMediaPaths 降级哨兵 — runner 符号缺失时返回，调用方走
  /// file_picker 旧路径。
  static const String fallback = '\u0000runner-dialog-fallback\u0000';

  static bool get _useNative =>
      Platform.environment['SIMPLER_PLAYER_FILE_DIALOG'] != 'legacy';

  static final ffi.DynamicLibrary _process = ffi.DynamicLibrary.process();

  static int _nextRequestId = 1;
  static final Map<int, Completer<String?>> _pendingCompleters = {};
  static final Map<int, ffi.NativeCallable<DialogResultNativeFn>>
  _callbackKeepalive = {};

  /// runner 返回码 → 语义结果（纯函数，单元测试覆盖）。
  ///
  /// 1=选中（[path] 即完整路径）；0=取消（null）；-1=参数错误；
  /// 其他负数 = HRESULT（低 32 位取反还原后以十六进制入错误消息）。
  @visibleForTesting
  static String? mapResult(int code, String path) => switch (code) {
    1 => path,
    0 => null,
    -1 => throw StateError(
      'RunnerFileDialog: dialog argument error (code=-1)',
    ),
    _ => throw StateError(
      'RunnerFileDialog: IFileOpenDialog failed '
      '(hr=0x${(-code).toRadixString(16)})',
    ),
  };

  /// 结果回调 — runner 线程经 NativeCallable.listener 唤起。
  static void _onDialogResult(
    int requestId,
    int code,
    ffi.Pointer<ffi.Uint16> pathPtr,
  ) {
    final path = pathPtr == ffi.nullptr
        ? null
        : pathPtr.cast<Utf16>().toDartString();
    RunnerDialogFreeString.call(pathPtr);
    _pendingCompleters.remove(requestId)?.complete(mapResult(code, path ?? ''));
  }

  /// 打开 runner 原生对话框（异步 — UI 不冻结）；返回 `null` = 用户取消。
  ///
  /// 返回 [fallback] 哨兵表示 runner 未导出符号（调用方降级）；
  /// 其他非空字符串 = 选中的媒体路径。HRESULT 错误抛 [StateError]。
  static Future<String?> show({
    required String extensionSpec,
    required bool lockParentWindow,
  }) async {
    if (!_useNative) return fallback;
    final process = _process;
    final showAsync = process.lookupFunction<
        ffi.Int32 Function(
            ffi.Pointer<ffi.Uint16>,
            ffi.Int32,
            ffi.Int32,
            ffi.Pointer<ffi.NativeFunction<DialogResultNativeFn>>),
        int Function(
            ffi.Pointer<ffi.Uint16>,
            int,
            int,
            ffi.Pointer<ffi.NativeFunction<DialogResultNativeFn>>)>(
      'SimplerPlayerShowOpenDialogAsync',
    );
    final requestId = _nextRequestId++;
    final completer = Completer<String?>();
    _pendingCompleters[requestId] = completer;
    final callback = ffi.NativeCallable<DialogResultNativeFn>.listener(
      _onDialogResult,
    );
    _callbackKeepalive[requestId] = callback;

    final specPtr = extensionSpec.toNativeUtf16();
    try {
      final accepted = showAsync(
        specPtr.cast<ffi.Uint16>(),
        lockParentWindow ? 1 : 0,
        requestId,
        callback.nativeFunction,
      );
      // runner 已在独立 STA 线程打开对话框；结果经 callback 回投。
      // （accepted != 0 仅为参数校验失败，正常路径恒为 0。）
      if (accepted != 0) {
        throw StateError(
          'RunnerFileDialog: async dialog rejected (code=$accepted)',
        );
      }
    } on ArgumentError {
      // 符号未导出（旧 runner 产物）— 降级 file_picker 路径。
      _pendingCompleters.remove(requestId);
      _callbackKeepalive.remove(requestId);
      callback.close();
      calloc.free(specPtr);
      return fallback;
    } finally {
      calloc.free(specPtr);
    }

    try {
      final result = await completer.future;
      return result;
    } finally {
      _pendingCompleters.remove(requestId);
      _callbackKeepalive.remove(requestId);
      callback.close();
    }
  }
}

/// C++ 分配的路径字符串释放（与 runner 的 `new wchar_t[]` 配对）。
abstract final class RunnerDialogFreeString {
  static final _free = RunnerFileDialog._process.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint16>),
      int Function(ffi.Pointer<ffi.Uint16>)>('SimplerPlayerFreeString');

  static void call(ffi.Pointer<ffi.Uint16> pathPtr) {
    if (pathPtr != ffi.nullptr) _free(pathPtr);
  }
}

/// [FilePickerMediaGateway] 的 runner 直调实现 — IME 包裹保留（对话框期间
/// 恢复 IMC，v0.0.8 msctf 崩溃防御），符号缺失时降级 file_picker 路径。
class RunnerFileDialogGateway implements FilePickerGateway {
  const RunnerFileDialogGateway();

  @override
  Future<List<String>?> pickMediaPaths() async {
    // 异步模式下不能再用 withImeRestored 包裹（action 立即返回，disable
    // 会在对话框存活期提前执行 → IMC 解除 → msctf 崩溃回归）。改为手动
    // enable/disable：enable 同步完成（同线程投递），disable 挂在结果
    // 之后 —— 对话框整个存活期 IMC 在位，与同步版时序等价。
    final bridge = Win32ImeBridge(logger: KernelLogger.I);
    bool restored = false;
    try {
      restored = bridge.enable();
    } on Object catch (error, stackTrace) {
      // 环境性失败（user32 绑定解析失败）与 withImeRestored 同义降级：
      // 未恢复就无从禁用，绝不让 Error 冲掉对话框调用。
      KernelLogger.I.warn(
        'RunnerFileDialogGateway: IME enable failed — proceeding '
        'without IME restore, closing disable skipped',
        context: <String, Object?>{
          'error': '$error',
          'stackTrace': '$stackTrace',
        },
      );
    }
    try {
      final result = await RunnerFileDialog.show(
        extensionSpec: PathValidator.supportedExtensions.join(';'),
        lockParentWindow: true,
      );
      if (result == RunnerFileDialog.fallback) {
        // 旧 runner 产物无符号 — 降级 file_picker（仍经 IME 包裹，同步
        // 版对话框用 withImeRestored 时序）。
        final legacy = await Win32ImeBridge.withImeRestored(
          () => FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: PathValidator.supportedExtensions,
            windowsOptions: const WindowsOptions(lockParentWindow: true),
          ),
        );
        if (legacy == null) return null;
        final path = legacy.path;
        return path == null ? const <String>[] : [path];
      }
      if (result == null) return null;
      return [result];
    } finally {
      if (restored) bridge.disable();
    }
  }
}
