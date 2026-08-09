import 'dart:io';

import '../utils/path_utils.dart';

/// 外部字幕输入的本地路径安全边界。
///
/// 该校验与媒体打开的 `PathValidator` 分离：字幕只允许本地文件，不能接受
/// 流媒体 URI；调用方可先用 [validate] 拒绝不安全语法，再用
/// [isLoadableLocalFile] 确认文件在使用时仍是受限大小的常规文件。
class SubtitlePathValidator {
  SubtitlePathValidator._();

  /// 手动与自动字幕加载共同支持的文件扩展名。
  static const supportedExtensions = <String>{
    '.srt',
    '.ass',
    '.ssa',
    '.sub',
    '.vtt',
    '.idx',
    '.sup',
  };

  /// 字幕解析前的最大文件大小，限制异常输入占用原生解析器资源。
  static const maxFileSizeBytes = 10 * 1024 * 1024;

  static final RegExp _controlCharacter = RegExp(r'[\x00-\x1F\x7F]');
  // `C:\video.srt` 是本地 Windows 路径；只拒绝 URI 形式而不把盘符误判为 scheme。
  static final RegExp _uriPrefix = RegExp(
    r'^(?:file:|[a-zA-Z][a-zA-Z0-9+.-]*://)',
  );
  static final RegExp _traversalSegment = RegExp(r'(^|[\\/])\.\.([\\/]|$)');

  /// 返回 `null` 表示 [path] 是允许的本地字幕路径；否则返回拒绝原因。
  ///
  /// 仅检查不依赖文件系统的语法，便于在路径抵达底层字幕解析器前快速拒绝
  /// URI、网络共享和遍历片段；不会拒绝 Unicode、空格或合法文件名中的 `..`。
  static String? validate(String path) {
    if (path.trim().isEmpty) return '字幕路径不能为空。';
    if (_controlCharacter.hasMatch(path)) return '字幕路径包含控制字符。';
    if (_uriPrefix.hasMatch(path)) return '字幕仅支持本地文件路径。';
    if (path.startsWith(r'\\') || path.startsWith('//')) {
      return '字幕不支持网络共享或设备路径。';
    }
    if (_traversalSegment.hasMatch(path)) return '字幕路径不能包含目录遍历片段。';

    final fileName = PathUtils.basename(path);
    final dotIndex = fileName.lastIndexOf('.');
    final extension = dotIndex > 0
        ? fileName.substring(dotIndex).toLowerCase()
        : '';
    if (!supportedExtensions.contains(extension)) {
      return '不支持的字幕文件格式。';
    }
    return null;
  }

  /// 确认 [path] 在使用瞬间仍是安全大小的本地常规文件。
  ///
  /// 文件系统状态可能在 picker 返回和引擎加载之间改变，因此这个检查必须紧邻
  /// `setExternalSubtitle` 调用执行；任何 I/O 异常均安全地拒绝加载。
  static Future<bool> isLoadableLocalFile(String path) async {
    if (validate(path) != null) return false;
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.file) return false;

      final length = await File(path).length();
      return length <= maxFileSizeBytes;
    } on FileSystemException {
      return false;
    }
  }
}
