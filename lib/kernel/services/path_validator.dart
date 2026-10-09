import '../models/validation_error.dart';

/// 路径安全校验工具 — 统一入口
///
/// Centralised file-path validation: extension whitelist, path-traversal
/// detection, and URL scheme filtering.
///
/// Invariants:
/// - All file-open entry points (FilePicker, drag-and-drop, history replay)
///   must pass through [validate] before reaching the engine.
/// - Extension lists are lowercase, without leading dots.
/// - [classify] 是五分支判定的单一实现；[validate] 只是
///   classify + messageFor 的委托外观 — 不得另建第二套分支逻辑，
///   保证判定与消息各有唯一真相源 (N2, T-261009fiy-02)。
class PathValidator {
  PathValidator._();

  /// FilePicker 使用的扩展名列表（不含点号，小写）
  ///
  /// A const list of lowercase extensions (no leading dot) accepted by
  /// the file picker. Must stay in sync with [allowedExtensions].
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
    // SMPTE 377M 广播封装 — libmpv/FFmpeg 内建 mxf demuxer(OP1a/OP-Atom)，
    // 内部 MPEG-2/H.264/ProRes/DNxHD 等常规编码可解；上限取决于具体编码。
    'mxf',
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
  ///
  /// Derived from [supportedExtensions]. Used by [isAllowedMedia] for
  /// O(1) membership checks.
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

  /// 检查路径是否为支持的流媒体 URL（scheme 前缀大小写不敏感）
  ///
  /// Returns `true` if [path] starts with a recognised streaming protocol
  /// (http, https, rtmp, rtsp, srt, udp, tcp), case-insensitively —
  /// Windows 用户直觉全系统大小写不敏感，`HTTP://HOST/v.mp4` 不再被误判
  /// 本地文件拒为"不支持的文件类型" (N1)。
  ///
  /// 大小写折叠只在输入侧做一次（[String.toLowerCase]）；[_urlSchemes]
  /// 集合本身保持全小写不变 — 比较集不放宽，fail-closed 语义保持。
  static bool isUrl(String path) {
    final lower = path.toLowerCase();
    return _urlSchemes.any(lower.startsWith);
  }

  /// 检查扩展名是否为允许的媒体类型
  ///
  /// Returns `true` if [path] is a URL (trusted upstream) or its lowercase
  /// extension is in [allowedExtensions].
  static bool isAllowedMedia(String path) {
    if (isUrl(path)) return true; // URL 信任上游
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return false;
    final ext = path.substring(dotIndex + 1).toLowerCase();
    return allowedExtensions.contains(ext);
  }

  /// 检查路径是否包含路径遍历攻击特征
  ///
  /// Returns `true` if [path] contains null bytes, `../` / `..\` sequences,
  /// UNC network paths (`\\`), or home-directory expansion (`~`).
  /// Does NOT flag bare `..` to avoid false positives on filenames
  /// like `song (live..remix).flac`.
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

  /// 校验失败类别判定 — 五分支检查的单一实现 (N2)
  ///
  /// Classifies a validation failure for [path] after single-point trim,
  /// returning the failure category, or `null` when the path is valid.
  /// Branch order is the decision order of [validate] — callers must not
  /// re-derive categories from the message string.
  ///
  /// 判定顺序与重构前 validate 逐分支恒同（空 → URL → 控制字符 →
  /// 路径遍历 → 扩展名白名单），对一切输入的类别决定与 validate 的
  /// accept/reject 决定一一对应（零漂移，T-261009fiy-02）。
  static ValidationErrorType? classify(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return ValidationErrorType.empty;
    if (isUrl(trimmed)) {
      // N1 语义继承: 门控对 trimmed 的小写形式做前缀比较，与 isUrl 的
      // 大小写不敏感语义同步 — 大写 `HTTP://`(无 authority) 仍被判
      // invalidUrl，不放行。
      if (!_hasValidHttpAuthority(trimmed)) {
        return ValidationErrorType.invalidUrl;
      }
      return null; // 其他协议（RTSP/RTMP/SRT/UDP/TCP）跳过
    }
    if (_hasControlCharacters(trimmed)) {
      return ValidationErrorType.controlCharacters;
    }
    if (isPathTraversal(trimmed)) return ValidationErrorType.pathTraversal;
    if (!isAllowedMedia(trimmed)) return ValidationErrorType.unsupportedFormat;
    return null;
  }

  /// HTTP/HTTPS authority 结构化门 — classify 专用私有判定 (N2)
  ///
  /// Returns `true` when [path] is not an http/https URL (no authority
  /// check applies), or when its Uri carries a non-empty host.
  /// Mirrors the pre-refactor validate branch byte-for-byte:
  /// `Uri.tryParse` 失败 / 无 authority / host 为空 都算无效。
  static bool _hasValidHttpAuthority(String path) {
    final lower = path.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return true; // 非 http(s) scheme — 无需 authority 校验
    }
    final uri = Uri.tryParse(path);
    return uri != null && uri.hasAuthority && uri.host.isNotEmpty;
  }

  /// 校验失败消息单一来源 — 按类别返回人类可读中文消息 (N2)
  ///
  /// Single source for the five validation messages. Text is byte-identical
  /// to the pre-refactor [validate] output (消息内嵌 trim 后串);
  /// drop_handler 校验门与 validationError 通知器依赖这些原文。
  static String messageFor(ValidationErrorType type, String path) {
    final trimmed = path.trim();
    return switch (type) {
      ValidationErrorType.empty => '路径为空',
      ValidationErrorType.invalidUrl => 'URL 格式无效: $trimmed',
      ValidationErrorType.controlCharacters => '路径包含非法控制字符: $trimmed',
      ValidationErrorType.pathTraversal => '路径不安全: $trimmed',
      ValidationErrorType.unsupportedFormat => '不支持的文件类型: $trimmed',
      // classify 现不产生 invalidPath（文件系统层校验未接入）——穷举保留臂，
      // 防未来追加类别时漏配文案。
      ValidationErrorType.invalidPath => '路径无效: $trimmed',
    };
  }

  /// 完整校验：扩展名 + 路径遍历
  ///
  /// Runs the full validation pipeline: empty check, URL scheme validation
  /// (HTTP/HTTPS require a valid authority), control-character scan,
  /// path-traversal detection, and extension whitelist.
  ///
  /// Returns `null` when [path] is valid, or a human-readable error string.
  /// 委托实现：switch (classify) + messageFor — 对外签名与消息文本不变，
  /// accept/reject 决定逐输入恒同（单一真相源，N2 重构）。
  static String? validate(String path) {
    return switch (classify(path)) {
      null => null,
      final type => messageFor(type, path),
    };
  }

  /// 批量校验，返回通过校验的路径列表
  ///
  /// Filters [paths] through [validate], keeping only entries that
  /// return `null` (valid). Preserves original order.
  static List<String> filterValid(List<String> paths) {
    return paths.where((p) => validate(p) == null).toList();
  }
}
