import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/value_listenable_builder2.dart';

/// 错误横幅 — 显示可操作的错误信息
///
/// 通过 [PlayerError] sealed class 的穷举模式匹配，
/// 根据错误子类型显示不同的操作按钮（重新打开 / 选择其他文件 / 重试）。
class ErrorBanner extends StatelessWidget {
  /// 引擎只读状态视图 — 提供 [state] 和 [lastError]
  final EngineStateView engine;

  /// 文件/编解码错误时的"打开文件"回调
  final VoidCallback? onOpenFile;

  /// 播放/网络错误时的"重试"回调
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.engine,
    this.onOpenFile,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<MediaState, PlayerError?>(
      first: engine.state,
      second: engine.lastError,
      builder: (context, state, error, _) {
        if (state != MediaState.error || error == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        // l10nKey 翻译 — 解耦 sealed 内部与 UI 显示文本 (D7)
        final displayMessage = _resolveMessage(l10n, error);

        // PlayerError sealed class 穷举匹配 — 根据子类型决定操作按钮
        VoidCallback? callback;
        String actionLabel;
        switch (error) {
          case FileError():
            callback = onOpenFile;
            actionLabel = l10n.reopen;
          case CodecError():
            callback = onOpenFile;
            actionLabel = l10n.selectOtherFile;
          // textureFailed 多为 GPU/驱动/4K 资源问题，盲目重试易触发资源竞争再超时
          // （实测：首次 4K open 成功但黑屏，用户再点 → 第二次 open 在首次纹理
          // 资源未释放时 5s 超时）。引导"选择其他文件"跳出死循环。
          // textureFailed 与 onOpenFile 共用同一恢复入口，避免重复打开失败资源。
          case PlaybackError(:final code)
              when code == PlaybackErrorCode.textureFailed:
            callback = onOpenFile;
            actionLabel = l10n.selectOtherFile;
          case PlaybackError() || NetworkError() || UnknownError():
            callback = onRetry;
            actionLabel = l10n.retry;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Tokens.danger.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Tokens.textPrimary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayMessage,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (callback != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: callback,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Tokens.textPrimary,
                      fontSize: Tokens.fontCaption,
                      fontWeight: Tokens.weightMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// l10nKey → AppLocalizations 查找，未知键 fallback 到原始 error.message (D7)
  ///
  /// Uses switch expression for compile-time exhaustive checking when new error
  /// codes are added. The `_` default case provides graceful fallback.
  String _resolveMessage(AppLocalizations l10n, PlayerError error) {
    return switch (error.l10nKey) {
      'error.file.pathEmpty' => l10n.errorFilePathEmpty,
      'error.file.fileNotFound' => l10n.errorFileNotFound,
      'error.file.pathTraversal' => l10n.errorFilepathTraversal,
      'error.codec.unsupportedFormat' => l10n.errorCodecUnsupportedFormat,
      'error.codec.decodeFailed' => l10n.errorCodecDecodeFailed,
      'error.codec.codecUnsupported' => l10n.errorCodecCodecUnsupported,
      'error.playback.playFailed' => l10n.errorPlaybackPlayFailed,
      'error.playback.seekFailed' => l10n.errorPlaybackSeekFailed,
      'error.playback.textureFailed' => l10n.errorPlaybackTextureFailed,
      'error.playback.openTimeout' => l10n.errorPlaybackOpenTimeout,
      'error.network.timeout' => l10n.errorNetworkTimeout,
      'error.network.connectionLost' => l10n.errorNetworkConnectionLost,
      'error.unknown' => l10n.errorUnknown,
      _ => error.message, // fallback: 未知 l10nKey 用原始消息
    };
  }
}
