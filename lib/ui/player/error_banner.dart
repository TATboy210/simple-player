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
                  error.message,
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
}
