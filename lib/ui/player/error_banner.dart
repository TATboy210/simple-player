import 'package:flutter/material.dart';

import 'package:player_engine/player_engine.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/value_listenable_builder2.dart';

/// 错误横幅 — 显示可操作的错误信息
class ErrorBanner extends StatelessWidget {
  final PlayerEngine engine;
  final VoidCallback? onOpenFile;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.engine,
    this.onOpenFile,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<MediaState, String?>(
      first: engine.state,
      second: engine.errorMessage,
      builder: (context, state, msg, _) {
        if (state != MediaState.error || msg == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);

        VoidCallback? callback;
        String actionLabel;
        switch (engine.errorType) {
          case MediaErrorType.file:
            callback = onOpenFile;
            actionLabel = l10n.reopen;
          case MediaErrorType.codec:
            callback = onOpenFile;
            actionLabel = l10n.selectOtherFile;
          case MediaErrorType.playback:
          case MediaErrorType.network:
          case MediaErrorType.unknown:
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
                  msg,
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
