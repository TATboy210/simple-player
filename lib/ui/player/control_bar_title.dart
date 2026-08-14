import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

/// 控制栏标题文本，保持标题对齐、截断和视觉样式稳定。
class _ControlBarTitleText extends StatelessWidget {
  final String? value;
  final bool minimal;

  const _ControlBarTitleText({required this.value, required this.minimal});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      value ?? '',
      style: TextStyle(
        color: Tokens.textPrimary,
        fontSize: minimal ? Tokens.fontCaption : Tokens.fontBody,
        fontWeight: Tokens.weightMedium,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
