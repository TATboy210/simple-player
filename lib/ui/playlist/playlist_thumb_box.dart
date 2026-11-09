import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'playlist_film_button.dart';
import 'playlist_tokens.dart';

/// 条目缩略图盒 — 缩略图 + 批量勾选圆标 / 透明"塑料膜"按钮层.
///
/// Thumbnail box. 非批量模式: 膜层 ClipRRect 与缩略图同款圆角覆盖整个
/// 缩略图 (播放 3/5 上 + 断点续播 2/5 下, 用户钦定); 批量模式: 膜层让位,
/// 右上角显示勾选圆标 (v0.0.7).
class PlaylistThumbBox extends StatelessWidget {
  /// 创建缩略图盒.
  const PlaylistThumbBox({
    super.key,
    required this.thumbnail,
    required this.selectionMode,
    required this.isSelected,
    required this.canResume,
    required this.onPlay,
    required this.onResume,
  });

  /// 缩略图本体 (含占位/淡入).
  final Widget thumbnail;

  /// 批量选择模式.
  final bool selectionMode;

  /// 批量选中态.
  final bool isSelected;

  /// 是否可续播 (有有效断点且总开关开启) — 否则续播分区禁用.
  final bool canResume;

  /// 播放回调.
  final VoidCallback onPlay;

  /// 断点续播回调.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PlaylistTokens.thumbWidth,
      height: PlaylistTokens.thumbHeight,
      child: Stack(
        children: [
          Positioned.fill(child: thumbnail),
          if (selectionMode) _selectBadge() else _filmLayer(context),
        ],
      ),
    );
  }

  /// 批量选中指示 — 右上角勾选圆标.
  Widget _selectBadge() {
    return Positioned(
      top: PlaylistTokens.selectBadgeInset,
      right: PlaylistTokens.selectBadgeInset,
      child: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: PlaylistTokens.selectBadgeSize,
        color: isSelected ? Tokens.accent : Tokens.textSecondary,
      ),
    );
  }

  /// 塑料膜按钮层 — 播放 (上 3/5) + 断点续播 (下 2/5).
  Widget _filmLayer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: Column(
          children: [
            Expanded(
              flex: PlaylistTokens.filmPlayFlex,
              child: PlaylistFilmButton(
                icon: Icons.play_arrow,
                label: l10n.play,
                onTap: onPlay,
              ),
            ),
            Expanded(
              flex: PlaylistTokens.filmResumeFlex,
              child: PlaylistFilmButton(
                icon: Icons.replay,
                label: l10n.resumePlayback,
                enabled: canResume,
                onTap: canResume ? onResume : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
