import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: PathValidator.supportedExtensions,
      lockParentWindow: true,
    );
    if (result == null) return null;

    return result.files
        .map((file) => file.path)
        .whereType<String>()
        .toList(growable: false);
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
