/// mpv 打开失败 → 项目 [PlayerError] 映射 — 纯函数, 单测不依赖 native libmpv.
///
/// mpv_kit reports a failed load as [MpvPlaybackError] (`end-file` with
/// reason `error`). Only the mpv codes with an unambiguous project meaning
/// get a typed error; everything else stays [UnknownError] with mpv's own
/// message, so no failure is mislabelled.
library;

import 'package:mpv_kit_video/mpv_kit_video.dart';

import '../models/player_error.dart';

/// 映射一次打开失败. [path] 为失败条目 (队列镜像当前项), [fileExists] 供
/// loadingFailed 区分"文件不存在"与其他装载失败 (网络/权限/协议).
PlayerError playerErrorFromMpv(
  MpvPlaybackError e, {
  String? path,
  bool Function(String path)? fileExists,
}) {
  final context = ErrorContext(
    action: 'mpv.end-file',
    module: 'MpvKitEngine',
    path: path,
  );
  final message = '${e.message} (${e.error.name})';
  return switch (e.error) {
    // 容器/编码无法识别, 或文件里没有可播放的音视频流.
    MpvError.unknownFormat || MpvError.nothingToPlay => CodecError(
      CodecErrorCode.unsupportedFormat,
      message,
      e,
      context,
    ),
    // 输出设备初始化失败 — 文件本身没问题, 是播放链路问题.
    MpvError.aoInitFailed || MpvError.voInitFailed => PlaybackError(
      PlaybackErrorCode.playFailed,
      message,
      e,
      context,
    ),
    MpvError.loadingFailed
        when path != null &&
            _isLocalPath(path) &&
            fileExists != null &&
            !fileExists(path) =>
      FileError(FileErrorCode.fileNotFound, message, e, context),
    _ => UnknownError(message, e, context),
  };
}

/// 非 URL 即本地路径 (`scheme://` 前缀判定; Windows 盘符 `C:` 不含 `//`).
bool _isLocalPath(String path) => !path.contains('://');
