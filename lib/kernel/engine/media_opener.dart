import 'dart:io' show File;

import '../models/player_error.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'models/video_codec_info.dart';

import '../services/path_validator.dart';
import '../utils/path_utils.dart';
import 'network_configurator.dart';
import 'open_result.dart';
import 'player_proxy.dart';
import 'track_manager.dart';

/// 媒体打开器 — 编排打开流程.
///
/// Media opener — orchestrates the open flow.
///
/// Responsibilities:
///   - Path validation (empty path, file existence).
///   - Network configuration delegation.
///   - MDK prepare + timeout.
///   - Metadata parsing (video/audio/subtitle tracks).
///   - D3D11 texture creation.
///
/// Returns [OpenResult] — success or typed error reason.
class MediaOpener {
  final MdkPlayerLike _player;
  final TrackManager _trackManager;

  static const _prepareTimeoutSeconds = 10;
  static const _textureTimeoutSeconds = 5;

  // 本地文件缓冲参数 — 紧凑配置，减少内存占用
  static const _localBufferMinMs = 500; // 默认 1000
  static const _localBufferMaxMs = 2000; // 默认 4000

  MediaOpener(this._player, this._trackManager);

  /// 打开媒体文件或 URL.
  ///
  /// Opens a media file or URL. Caller checks [OpenResult] type:
  /// - [OpenSuccess]: ready to play.
  /// - [OpenError]: contains typed error and message.
  Future<OpenResult> open(String path) async {
    // ─── 路径验证 ───
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return OpenError(
        FileError(
          FileErrorCode.pathEmpty,
          '文件路径为空',
          null,
          ErrorContext(action: 'open', path: trimmed, module: 'MediaOpener'),
        ),
      );
    }

    // 非 URL 路径检查文件是否存在
    if (!PathValidator.isUrl(trimmed)) {
      try {
        final file = File(trimmed);
        if (!await file.exists()) {
          return OpenError(
            FileError(
              FileErrorCode.fileNotFound,
              '文件不存在: ${PathUtils.basename(trimmed)}',
              null,
              ErrorContext(action: 'open', path: trimmed, module: 'MediaOpener'),
            ),
          );
        }
      } on Exception catch (e) {
        return OpenError(
          FileError(
            FileErrorCode.fileNotFound,
            '路径无效: $e',
            e,
            ErrorContext(action: 'open', path: trimmed, module: 'MediaOpener'),
          ),
        );
      }
    }

    // ─── Prepare ───
    _player.media = trimmed;

    if (PathValidator.isUrl(trimmed)) {
      NetworkConfigurator.configure(_player, trimmed);
    } else {
      _configureLocalBuffer();
    }

    final prepareResult = await _player.prepare().timeout(
      const Duration(seconds: _prepareTimeoutSeconds),
      onTimeout: () => -99,
    );
    if (prepareResult < 0) {
      final isTimeout = prepareResult == -99;
      final ctx = ErrorContext(action: 'prepare', path: trimmed, module: 'MediaOpener');
      final PlayerError error;
      if (isTimeout) {
        error = PathValidator.isUrl(trimmed)
            ? NetworkError(NetworkErrorCode.timeout, '打开超时: ${PathUtils.basename(trimmed)}', null, ctx)
            : FileError(FileErrorCode.fileNotFound, '打开超时: ${PathUtils.basename(trimmed)}', null, ctx);
      } else {
        error = CodecError(CodecErrorCode.decodeFailed, '无法解码: ${PathUtils.basename(trimmed)} (code: $prepareResult)', null, ctx);
      }
      return OpenError(error);
    }

    // ─── Metadata 解析 ───
    // mediaInfo 是 dynamic（mdk.MediaInfo 或 FakeMdkMediaInfo），
    // 使用 _extract* 辅助方法安全提取字段，兼容 strict-casts 模式。
    final dynamic info = _player.mediaInfo;

    // PAR 修正：物理像素宽高比 ≠ 显示宽高比
    VideoCodecInfo? videoInfo;
    final List<dynamic>? videos = info.video as List<dynamic>?;
    if (videos != null && videos.isNotEmpty) {
      final dynamic vc = videos.first.codec;
      final int w = vc.width as int;
      final int h = vc.height as int;
      if (w > 0 && h > 0) {
        videoInfo = VideoCodecInfo(
          width: w,
          height: h,
          par: (vc.par as num).toDouble(),
          codec: vc.codec as String,
        );
      }
    }

    // 音轨信息
    final audioTracks = _parseAudioTracks(info);

    // 字幕轨道信息
    final subtitleTracks = _parseSubtitleTracks(info);

    final mediaInfo = MediaInfo(
      duration: info.duration as int,
      video: videoInfo,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
    );
    _trackManager.updateMediaInfo(mediaInfo);

    // ─── 纹理创建 ───
    final textureResult = await _player.updateTexture().timeout(
      const Duration(seconds: _textureTimeoutSeconds),
      onTimeout: () => -99,
    );
    if (textureResult < 0) {
      final message = textureResult == -99
          ? '纹理创建超时: ${PathUtils.basename(trimmed)}'
          : '纹理创建失败: ${PathUtils.basename(trimmed)}';
      return OpenError(
        PlaybackError(
          PlaybackErrorCode.textureFailed,
          message,
          null,
          ErrorContext(action: 'texture', path: trimmed, module: 'MediaOpener'),
        ),
      );
    }

    // updateTexture() 返回码 >=0 但 textureId 仍为 null — D3D11 纹理创建静默失败
    if (_player.textureId.value == null) {
      return OpenError(
        PlaybackError(
          PlaybackErrorCode.textureFailed,
          '纹理创建失败(空 textureId): ${PathUtils.basename(trimmed)}',
          null,
          ErrorContext(action: 'texture', path: trimmed, module: 'MediaOpener'),
        ),
      );
    }

    return OpenSuccess(mediaInfo);
  }

  /// 本地文件紧凑缓冲 — 减少内存占用
  void _configureLocalBuffer() {
    _player.setBufferRange(
      min: _localBufferMinMs,
      max: _localBufferMaxMs,
      drop: true,
    );
    _player.setProperty('demux.buffer.ranges', '0');
  }

  /// 解析音轨信息 — 动态类型兼容 mdk.MediaInfo 和 FakeMdkMediaInfo
  List<AudioTrackInfo> _parseAudioTracks(dynamic info) {
    final audioTracks = <AudioTrackInfo>[];
    final dynamic audio = info.audio;
    if (audio != null) {
      for (final dynamic t in (audio as List)) {
        audioTracks.add(
          AudioTrackInfo(
            index: t.index as int,
            language: (t.metadata as Map)['language'] as String? ?? '',
            codec: (t.codec.codec as String),
            channels: t.codec.channels as int,
          ),
        );
      }
    }
    return audioTracks;
  }

  /// 解析字幕轨道信息 — 动态类型兼容 mdk.MediaInfo 和 FakeMdkMediaInfo
  List<SubtitleTrackInfo> _parseSubtitleTracks(dynamic info) {
    final subtitleTracks = <SubtitleTrackInfo>[];
    final dynamic subtitle = info.subtitle;
    if (subtitle != null) {
      for (final dynamic t in (subtitle as List)) {
        subtitleTracks.add(
          SubtitleTrackInfo(
            index: t.index as int,
            language: (t.metadata as Map)['language'] as String? ?? '',
            title: (t.metadata as Map)['title'] as String? ?? '',
          ),
        );
      }
    }
    return subtitleTracks;
  }
}
