import 'dart:io' show File;

import 'package:fvp/mdk.dart' as mdk;
import 'package:player_engine/player_engine.dart';

import '../services/path_validator.dart';
import '../utils/path_utils.dart';
import 'network_configurator.dart';
import 'open_result.dart';
import 'track_manager.dart';

/// 媒体打开器 — 编排打开流程
///
/// 职责:
///   - 路径验证（空路径、文件存在性）
///   - 网络配置委托
///   - MDK prepare + 超时
///   - metadata 解析（视频/音频/字幕轨）
///   - D3D11 纹理创建
///
/// 返回 [OpenResult] 表示成功或失败原因。
class MediaOpener {
  final mdk.Player _player;
  final TrackManager _trackManager;

  static const _prepareTimeoutSeconds = 10;
  static const _textureTimeoutSeconds = 5;

  // 本地文件缓冲参数 — 紧凑配置，减少内存占用
  static const _localBufferMinMs = 500; // 默认 1000
  static const _localBufferMaxMs = 2000; // 默认 4000

  MediaOpener(this._player, this._trackManager);

  /// 打开媒体文件或 URL
  ///
  /// 调用方需在返回后检查 [OpenResult] 类型:
  /// - [OpenSuccess]: 打开成功，可开始播放
  /// - [OpenError]: 打开失败，包含错误类型和消息
  Future<OpenResult> open(String path) async {
    // ─── 路径验证 ───
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return const OpenError(MediaErrorType.file, '文件路径为空');
    }

    // 非 URL 路径检查文件是否存在
    if (!PathValidator.isUrl(trimmed)) {
      try {
        final file = File(trimmed);
        if (!await file.exists()) {
          return OpenError(
            MediaErrorType.file,
            '文件不存在: ${PathUtils.basename(trimmed)}',
          );
        }
      } on Exception catch (e) {
        return OpenError(MediaErrorType.file, '路径无效: $e');
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
      final errorType = isTimeout
          ? (PathValidator.isUrl(trimmed)
                ? MediaErrorType.network
                : MediaErrorType.file)
          : MediaErrorType.codec;
      final message = isTimeout
          ? '打开超时: ${PathUtils.basename(trimmed)}'
          : '无法解码: ${PathUtils.basename(trimmed)} (code: $prepareResult)';
      return OpenError(errorType, message);
    }

    // ─── Metadata 解析 ───
    final info = _player.mediaInfo;

    // PAR 修正：物理像素宽高比 ≠ 显示宽高比
    final videos = info.video;
    VideoCodecInfo? videoInfo;
    if (videos != null && videos.isNotEmpty) {
      final vc = videos.first.codec;
      if (vc.width > 0 && vc.height > 0) {
        videoInfo = VideoCodecInfo(
          width: vc.width,
          height: vc.height,
          par: vc.par,
          codec: vc.codec,
        );
      }
    }

    // 音轨信息
    final audioTracks = _parseAudioTracks(info);

    // 字幕轨道信息
    final subtitleTracks = _parseSubtitleTracks(info);

    final mediaInfo = MediaInfo(
      duration: info.duration,
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
      return OpenError(MediaErrorType.codec, message);
    }

    return OpenSuccess(mediaInfo);
  }

  /// 本地文件紧凑缓冲 — 减少内存占用
  ///
  /// 默认 buffer.range=1000-4000ms，本地文件不需要这么大的缓冲。
  /// 同时禁用 demux 缓存（网络流才需要）。
  void _configureLocalBuffer() {
    _player.setBufferRange(
      min: _localBufferMinMs,
      max: _localBufferMaxMs,
      drop: true,
    );
    _player.setProperty('demux.buffer.ranges', '0');
  }

  /// 解析音轨信息
  List<AudioTrackInfo> _parseAudioTracks(mdk.MediaInfo info) {
    final audioTracks = <AudioTrackInfo>[];
    final audio = info.audio;
    if (audio != null) {
      for (final t in audio) {
        audioTracks.add(
          AudioTrackInfo(
            index: t.index,
            language: t.metadata['language'] ?? '',
            codec: t.codec.codec,
            channels: t.codec.channels,
          ),
        );
      }
    }
    return audioTracks;
  }

  /// 解析字幕轨道信息
  List<SubtitleTrackInfo> _parseSubtitleTracks(mdk.MediaInfo info) {
    final subtitleTracks = <SubtitleTrackInfo>[];
    final subtitle = info.subtitle;
    if (subtitle != null) {
      for (final t in subtitle) {
        subtitleTracks.add(
          SubtitleTrackInfo(
            index: t.index,
            language: t.metadata['language'] ?? '',
            title: t.metadata['title'] ?? '',
          ),
        );
      }
    }
    return subtitleTracks;
  }
}
