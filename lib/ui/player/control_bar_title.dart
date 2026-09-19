import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/marquee_text.dart';
import '../theme/tokens.dart';

/// 控制栏标题行，保持标题独占空间以免挤压时间读数。
class ControlBarTitle extends StatelessWidget {
  final String? title;
  final ValueListenable<String>? titleListenable;

  /// 最小模式降低标题字号，避免在窄窗口中抢占时间轴空间。
  final bool minimal;

  const ControlBarTitle({
    super.key,
    this.title,
    this.titleListenable,
    this.minimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = titleListenable;
    if (listenable == null) {
      return _ControlBarTitleText(value: title, minimal: minimal);
    }

    return ValueListenableBuilder<String>(
      valueListenable: listenable,
      builder: (_, value, _) => _ControlBarTitleText(
        // 动态标题尚未就绪时保留静态首帧标题，避免异步 notifier 清空标题。
        value: value.isEmpty ? title : value,
        minimal: minimal,
      ),
    );
  }
}

/// 控制栏标题文本，保持标题对齐和视觉样式稳定；
/// 超长文件名由 [MarqueeText] 往返滚动完整展示，不再 ellipsis 截断。
class _ControlBarTitleText extends StatelessWidget {
  final String? value;
  final bool minimal;

  const _ControlBarTitleText({required this.value, required this.minimal});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: MarqueeText(
      text: value ?? '',
      style: TextStyle(
        color: Tokens.textPrimary,
        fontSize: minimal ? Tokens.fontCaption : Tokens.fontBody,
        fontWeight: Tokens.weightMedium,
      ),
    ),
  );
}
