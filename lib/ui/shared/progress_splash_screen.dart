import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../kernel/startup/startup_state.dart';

/// 进度感知的启动 Splash
///
/// 接收 [StartupState]，根据阶段显示：
/// - 未开始：品牌名 + 不定进度圈（与原启动 splash 一致）
/// - 进行中：品牌名 + 线性进度条 + 阶段消息
/// - 完成后：由 AnimatedSwitcher 切换到主 UI
class ProgressSplashScreen extends StatelessWidget {
  const ProgressSplashScreen({super.key, required this.state});

  final StartupState state;

  static const _brandName = 'S I M P L E   P L A Y E R';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              _brandName,
              style: TextStyle(
                fontSize: Tokens.fontBranding,
                fontWeight: Tokens.weightExtraLight,
                color: Tokens.textPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: Tokens.spXl),
            SizedBox(
              width: 160,
              child: state.progress > 0
                  ? _DeterminateProgress(
                      progress: state.progress,
                      message: state.message,
                    )
                  : const _IndeterminateProgress(),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndeterminateProgress extends StatelessWidget {
  const _IndeterminateProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.accent),
    );
  }
}

class _DeterminateProgress extends StatelessWidget {
  const _DeterminateProgress({required this.progress, required this.message});

  final double progress;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Tokens.bgElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(Tokens.accent),
            minHeight: 2,
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: Tokens.spSm),
          Text(
            message,
            style: const TextStyle(
              color: Tokens.textTertiary,
              fontSize: Tokens.fontCaption,
            ),
          ),
        ],
      ],
    );
  }
}
