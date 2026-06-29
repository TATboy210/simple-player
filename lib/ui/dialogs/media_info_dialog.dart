import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_dialog.dart';

/// 视频属性对话框 — 显示媒体文件的元数据信息
class MediaInfoDialog extends StatelessWidget {
  final String path;
  final MediaInfo info;

  const MediaInfoDialog({super.key, required this.path, required this.info});

  static Future<void> show(
    BuildContext context, {
    required String path,
    required MediaInfo info,
  }) {
    return showDialog(
      context: context,
      builder: (_) => MediaInfoDialog(path: path, info: info),
    );
  }

  /// 从引擎便捷打开（需要引擎已加载文件）
  static Future<void> showForEngine(
    BuildContext context, {
    required String path,
    required EngineState engine,
  }) {
    return show(context, path: path, info: engine.mediaInfo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.propertiesDialog,
      width: 380,
      height: 360,
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Section(l10n.fileSection),
          _CopyableRow(l10n.filePath, path),
          _CopyableRow(l10n.fileName, _basename(path)),

          if (info.video case final vid?) ...[
            _Section(l10n.videoSection),
            _InfoRow(l10n.resolution, '${vid.width} × ${vid.height}'),
            _InfoRow(l10n.codec, vid.codec.toUpperCase()),
            if (vid.par != 1.0)
              _InfoRow(l10n.pixelAspectRatio, vid.par.toStringAsFixed(2)),
            _InfoRow(l10n.aspectRatioLabel, vid.aspectRatio.toStringAsFixed(2)),
          ],

          _Section(l10n.durationSection),
          _InfoRow(l10n.totalDuration, formatMs(info.duration)),

          if (info.hasAudio) ...[
            _Section(l10n.audioSection),
            _InfoRow(l10n.trackCount, '${info.audioTracks.length}'),
            for (final track in info.audioTracks)
              _InfoRow(
                l10n.trackN(track.index),
                [
                  if (track.language.isNotEmpty) track.language,
                  track.codec.toUpperCase(),
                  if (track.channels > 0) '${track.channels}ch',
                ].join(' · '),
              ),
          ],

          if (info.hasSubtitles) ...[
            _Section(l10n.subtitleSection),
            _InfoRow(l10n.trackCount, '${info.subtitleTracks.length}'),
            for (final track in info.subtitleTracks)
              _InfoRow(
                l10n.trackN(track.index),
                [
                  if (track.language.isNotEmpty) track.language,
                  if (track.title.isNotEmpty) track.title,
                ].join(' · ').ifEmpty(l10n.unknown),
              ),
          ],
        ],
      ),
    );
  }

  static String _basename(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Tokens.accent,
          fontSize: Tokens.fontCaption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Tokens.textSecondary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyableRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Tokens.textSecondary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.copied),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Tooltip(
                message: l10n.doubleClickToCopy,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _StringExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
