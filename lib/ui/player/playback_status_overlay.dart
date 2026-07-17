import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// 播放状态覆盖层 — 反馈打开媒体和等待数据的短暂状态。
///
/// 只观察引擎已公开的状态，不推断 Texture 是否实际呈现帧；
/// native texture 的可见性仍由 fvp/Windows 渲染链负责。
class PlaybackStatusOverlay extends StatelessWidget {
  /// 正在打开媒体时的稳定测试与语义定位标识。
  static const openingKey = Key('playback-status-opening');

  /// 正在缓冲数据时的稳定测试与语义定位标识。
  static const bufferingKey = Key('playback-status-buffering');

  /// 引擎只读状态视图，提供播放状态与缓冲信号。
  final EngineStateView engine;

  const PlaybackStatusOverlay({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // 状态反馈不能抢占视频区域的单击、双击和拖放手势。
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([engine.state, engine.isBuffering]),
          builder: (_, _) {
            final state = engine.state.value;
            final isOpening = state == MediaState.opening;
            final isBuffering =
                !isOpening &&
                state != MediaState.error &&
                state != MediaState.idle &&
                engine.isBuffering.value;

            if (!isOpening && !isBuffering) {
              return const SizedBox.shrink();
            }

            final l10n = AppLocalizations.of(context);
            return Semantics(
              key: isOpening ? openingKey : bufferingKey,
              label: isOpening ? l10n.openingMedia : l10n.bufferingMedia,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(Tokens.spMd),
                decoration: BoxDecoration(
                  color: Tokens.bgGlass,
                  borderRadius: BorderRadius.circular(Tokens.radiusMd),
                  border: Border.all(color: Tokens.glassBorder),
                ),
                child: const SizedBox(
                  width: Tokens.iconXl,
                  height: Tokens.iconXl,
                  child: CircularProgressIndicator(
                    color: Tokens.accent,
                    strokeWidth: Tokens.spXs,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
