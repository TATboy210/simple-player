import 'package:flutter/material.dart';

/// 「通用」分区内容 —— 错误卡片开关行与日志目录路径行的承载结构。
///
/// 布局骨架（04-04 Task 1）：构造参数面（[debounceDuration]/[directoryPicker]）
/// 先行落位使行为测试可编译；开关行与路径行的具体接线在 Task 2 实装。
/// 占位仅限布局骨架，不带任何假交互（Avoid captive UI）。
class GeneralSettingsContent extends StatelessWidget {
  const GeneralSettingsContent({
    super.key,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.directoryPicker,
  });

  /// 输入防抖时长 —— 生产默认 300ms（RESEARCH A2）；测试注入更短值。
  final Duration debounceDuration;

  /// 目录选择网关注入缝 —— file_picker 是 plugin 通道调用，headless 测试
  /// 不可用；注入假网关以测取消/回填。缺省绑定生产 FilePicker（Task 2）。
  final Future<String?> Function()? directoryPicker;

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
