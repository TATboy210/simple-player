import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../kernel/bridge/win32/ime_bridge.dart';
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
        () => RunnerFileDialog.show(
          extensionSpec: PathValidator.supportedExtensions.join(';'),
          lockParentWindow: true,
        ),
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

/// runner 主线程原生对话框通道（性能修复）。
///
/// `SimplerPlayerShowOpenDialog`（windows/runner/flutter_window.cpp）在
/// platform 线程直调 IFileOpenDialog —— 主线程 STA 已由引擎预热，避开
/// windows_file_picker 的 compute-isolate 冷 COM（点击→对话框 6~10s）。
///
/// 同步 FFI：对话框模态期间 Dart UI isolate 冻结在调用里 —— 与模态语义
/// 一致（对话框期间本无交互）。IME：调用前经 [Win32ImeBridge.enable] 同步
/// 恢复（同线程投递），对话框关闭后 finally 里 disable —— 与
/// withImeRestored 的包裹语义等价，但 enable/对话框/disable 全在同一线程
/// 串行，时序比跨线程更确定。
///
/// 返回码协议（runner 侧）：1=选中（`outPath` 含路径）、0=取消、
/// -1=参数错误、-2=路径超出缓冲、其他负数=HRESULT。
/// 符号缺失（旧 runner 产物）→ 返回 [sentinel] 触发调用方降级。
abstract final class RunnerFileDialog {
  /// pickMediaPaths 降级哨兵 — runner 符号缺失时返回，调用方走
  /// file_picker 旧路径。
  static const String fallback = '\u0000runner-dialog-fallback\u0000';

  static bool get _useNative =>
      Platform.environment['SIMPLER_PLAYER_FILE_DIALOG'] != 'legacy';

  /// runner 返回码 → 语义结果（纯函数，单元测试覆盖）。
  ///
  /// 1=选中（[path] 即完整路径）；0=取消（null）；-1/-2=参数与缓冲错误；
  /// 其他负数 = HRESULT（低 32 位取反还原后以十六进制入错误消息）。
  @visibleForTesting
  static String? mapResult(int code, String path) => switch (code) {
    1 => path,
    0 => null,
    -1 => throw StateError(
      'RunnerFileDialog: dialog argument error (code=-1)',
    ),
    -2 => throw StateError(
      'RunnerFileDialog: path exceeds Dart buffer capacity (code=-2)',
    ),
    _ => throw StateError(
      'RunnerFileDialog: IFileOpenDialog failed '
      '(hr=0x${(-code).toRadixString(16)})',
    ),
  };

  /// 打开 runner 原生对话框；返回 `null` = 用户取消。
  ///
  /// 返回 [fallback] 哨兵表示 runner 未导出符号（调用方降级）；
  /// 其他非空字符串 = 选中的媒体路径。HRESULT 错误抛 [StateError]。
  static Future<String?> show({
    required String extensionSpec,
    required bool lockParentWindow,
  }) async {
    if (!_useNative) return fallback;
    try {
      final process = ffi.DynamicLibrary.process();
      final show = process.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Uint16>, ffi.Int32,
              ffi.Pointer<ffi.Uint16>, ffi.Int32),
          int Function(ffi.Pointer<ffi.Uint16>, int,
              ffi.Pointer<ffi.Uint16>, int)>('SimplerPlayerShowOpenDialog');
      final specPtr = extensionSpec.toNativeUtf16();
      final outPath = calloc<ffi.Uint16>(32768);
      try {
        final code = show(
          specPtr.cast<ffi.Uint16>(),
          lockParentWindow ? 1 : 0,
          outPath,
          32768,
        );
        return mapResult(code, outPath.cast<Utf16>().toDartString());
      } finally {
        calloc.free(specPtr);
        calloc.free(outPath);
      }
    } on ArgumentError {
      // 符号未导出（旧 runner 产物）— 调用方降级到 file_picker 路径。
      return fallback;
    }
  }
}

/// [FilePickerMediaGateway] 的 runner 直调实现 — IME 包裹保留（对话框期间
/// 恢复 IMC，v0.0.8 msctf 崩溃防御），符号缺失时降级 file_picker 路径。
class RunnerFileDialogGateway implements FilePickerGateway {
  const RunnerFileDialogGateway();

  @override
  Future<List<String>?> pickMediaPaths() async {
    final result = await Win32ImeBridge.withImeRestored(
      () => RunnerFileDialog.show(
        extensionSpec: PathValidator.supportedExtensions.join(';'),
        lockParentWindow: true,
      ),
    );
    if (result == RunnerFileDialog.fallback) {
      // 旧 runner 产物无符号 — 降级 file_picker（与 FilePickerMediaGateway
      // 的落穿分支一致，仍经 IME 包裹）。
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
  }
}
