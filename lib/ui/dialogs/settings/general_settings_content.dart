import 'package:flutter/material.dart';

/// 「通用」分区内容 —— 错误卡片开关行与日志目录路径行的承载结构。
///
/// 布局骨架（04-04 Task 1）：开关行与路径行的具体接线在 Task 2 实装；
/// 占位仅限布局骨架，不带任何假交互（Avoid captive UI）。
class GeneralSettingsContent extends StatelessWidget {
  const GeneralSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 开关行占位 —— Task 2 接 ErrorFeedbackSettings.I.setCardEnabled。
        SizedBox(height: 40),
        // 路径行占位 —— Task 2 接 DiagnosticLogTarget.I.apply 全协议。
        SizedBox(height: 40),
      ],
    );
  }
}
