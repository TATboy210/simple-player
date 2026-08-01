import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 控制栏标题行，保持标题独占空间以免挤压时间读数。
class ControlBarTitle extends StatelessWidget {
  final String? title;

  const ControlBarTitle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title ?? '',
        style: const TextStyle(
          color: Tokens.textPrimary,
          fontSize: Tokens.fontBody,
          fontWeight: Tokens.weightMedium,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
