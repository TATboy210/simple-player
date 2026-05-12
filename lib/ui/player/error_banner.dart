import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// 错误操作类型
enum _ErrorActionType { reopen, selectOther, retry }

/// 错误横幅 — 显示可操作的错误信息
class ErrorBanner extends StatelessWidget {
  final MediaEngine engine;
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
    return ValueListenableBuilder<String?>(
      valueListenable: engine.errorMessage,
      builder: (context, msg, _) {
        if (engine.state.value != MediaState.error || msg == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final actionType = _parseErrorAction(msg);

        VoidCallback? callback;
        String actionLabel;
        switch (actionType) {
          case _ErrorActionType.reopen:
            callback = onOpenFile;
            actionLabel = l10n.reopen;
          case _ErrorActionType.selectOther:
            callback = onOpenFile;
            actionLabel = l10n.selectOtherFile;
          case _ErrorActionType.retry:
            callback = onRetry;
            actionLabel = l10n.retry;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Tokens.danger.withAlpha(200),
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
                    fontSize: 13,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  static _ErrorActionType _parseErrorAction(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('file') ||
        lower.contains('文件') ||
        lower.contains('not found') ||
        lower.contains('找不到') ||
        lower.contains('no such') ||
        lower.contains('path') ||
        lower.contains('路径')) {
      return _ErrorActionType.reopen;
    }
    if (lower.contains('codec') ||
        lower.contains('解码') ||
        lower.contains('unsupported') ||
        lower.contains('format')) {
      return _ErrorActionType.selectOther;
    }
    return _ErrorActionType.retry;
  }
}
