/// 路径安全校验工具
///
/// 统一的文件路径校验：扩展名白名单、路径遍历检测。
/// 所有文件打开入口（FilePicker、拖放、历史记录）必须通过此工具校验。
class PathValidator {
  PathValidator._();

  /// FilePicker 使用的扩展名列表（不含点号，小写）
  ///
  /// 与 [allowedExtensions] 保持同步，供 FilePicker 和 UI 层引用。
  static const supportedExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'flv',
    'm4v',
    'wmv',
    'webm',
    'ts',
    'mpeg',
    'mpg',
    '3gp',
    'ogv',
    'vob',
    'rmvb',
    'mp3',
    'flac',
    'wav',
    'aac',
    'ogg',
    'opus',
    'm4a',
    'wma',
    'ape',
    'alac',
    'aiff',
  ];

  /// 允许的媒体文件扩展名白名单（小写，从 supportedExtensions 派生）
  static final allowedExtensions = supportedExtensions.toSet();

  /// URL 协议白名单 — MDK/FFmpeg 原生支持
  static const _urlSchemes = {
    'http://',
    'https://',
    'rtmp://',
    'rtsp://',
    'srt://',
    'udp://',
    'tcp://',
  };

  /// 检查是否为 URL
  static bool isUrl(String path) => _urlSchemes.any((s) => path.startsWith(s));

  /// 检查扩展名是否为允许的媒体类型
  static bool isAllowedMedia(String path) {
    if (isUrl(path)) return true; // URL 信任上游
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return false;
    final ext = path.substring(dotIndex + 1).toLowerCase();
    return allowedExtensions.contains(ext);
  }

  /// 检查路径是否包含路径遍历攻击特征
  ///
  /// 只检测 `../` 和 `..\` 模式，不检测裸 `..`（避免误杀合法文件名
  /// 如 `song (live..remix).flac`）。
  static bool isPathTraversal(String path) {
    if (path.contains('\x00')) return true; // null byte 注入
    if (path.contains('../') || path.contains('..\\')) return true; // 路径遍历
    if (path.startsWith('\\\\')) return true; // UNC 网络路径
    if (path.startsWith('~')) return true; // home 目录展开
    return false;
  }

  /// 检查路径是否包含 ASCII 控制字符 (0x01-0x1F，排除 0x00 和 0x09)
  ///
  /// 0x00 已在 [isPathTraversal] 检测，0x09 (tab) 在 Windows 文件名中合法。
  static bool _hasControlCharacters(String path) {
    for (var i = 0; i < path.length; i++) {
      final code = path.codeUnitAt(i);
      if (code < 0x20 && code != 0x00 && code != 0x09) return true;
    }
    return false;
  }

  /// 完整校验：扩展名 + 路径遍历
  ///
  /// 返回 null = 合法，返回 String = 错误消息
  static String? validate(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '路径为空';
    if (isUrl(trimmed)) {
      // HTTP/HTTPS 需要结构化验证
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
          return 'URL 格式无效: $trimmed';
        }
      }
      return null; // 其他协议（RTSP/RTMP/SRT/UDP/TCP）跳过
    }
    if (_hasControlCharacters(trimmed)) {
      return '路径包含非法控制字符: $trimmed';
    }
    if (isPathTraversal(trimmed)) return '路径不安全: $trimmed';
    if (!isAllowedMedia(trimmed)) return '不支持的文件类型: $trimmed';
    return null;
  }

  /// 批量校验，返回通过校验的路径列表
  static List<String> filterValid(List<String> paths) {
    return paths.where((p) => validate(p) == null).toList();
  }
}
