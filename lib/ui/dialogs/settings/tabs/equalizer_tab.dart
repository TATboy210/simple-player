// EqualizerTab — 均衡器预设选择 tab（Phase 33）。
//
// 5 个固定 EQ 预设的 radio 选择器：关闭 / 低音增强 / 高音增强 / 摇滚 / 流行。
// 用户选择经 pending.update('eqPresetIndex', i) 延迟存储，Apply/OK 时由
// SettingsPanelController.commitPending() 构造 AudioSettings 快照交回调。
// 不直接调 service——纯 UI 投影 pending 状态（AUDIO-06 延迟应用）。
//
// 标签索引与 AudioFilterCompositor.eqPresets 表一一对应（0..4）；组合器内部
// 对索引额外 clamp 作纵深防御，故两处解耦安全。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 均衡器预设选择 tab（Phase 33）。
///
/// 5 个固定 EQ 预设 radio 行——选择经 [PendingSettingsState.update] 延迟存储，
/// 不直接调引擎。预设在 [AudioFilterCompositor.eqPresets] 中定义，此处仅持有
/// 本地化标签（索引与组合器表一一对应，由组合器测试 + 本 tab widget 测试覆盖）。
class EqualizerTab extends StatefulWidget {
  /// 延迟应用状态容器——由 SettingsPanelController 持有并注入。
  final PendingSettingsState pending;

  const EqualizerTab({super.key, required this.pending});

  @override
  State<EqualizerTab> createState() => _EqualizerTabState();
}

class _EqualizerTabState extends State<EqualizerTab> {
  /// EQ 预设本地化标签——索引与 AudioFilterCompositor.eqPresets 一一对应。
  static const _eqPresetLabels = <String>[
    '关闭', // 0
    '低音增强', // 1: bass=g=10
    '高音增强', // 2: treble=g=5
    '摇滚', // 3: bass=g=8,treble=g=6
    '流行', // 4: bass=g=3,treble=g=4
  ];

  /// 当前选中预设索引——从 pending 投影（pending 优先，回退 original 基准）。
  /// 读未注册键得 null→回退 0（纵深防御，正常路径下 open() 已注册）。
  int get _currentIndex {
    final v = widget.pending.current('eqPresetIndex');
    if (v is int) return v;
    return 0;
  }

  /// 选择预设——写入 pending 并触发本 widget 重建。
  ///
  /// pending 是纯数据容器（非 Listenable），故需手动 setState 刷新 radio 显示；
  /// 真正的引擎应用延迟到 Apply/OK 提交时（AUDIO-06）。
  void _select(int index) {
    widget.pending.update('eqPresetIndex', index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;
    return SingleChildScrollView(
      child: AnimatedSectionList(
        children: [
          GlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spLg,
              vertical: Tokens.spMd,
            ),
            margin: const EdgeInsets.only(bottom: Tokens.spMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: '均衡器预设', icon: Icons.equalizer),
                for (var i = 0; i < _eqPresetLabels.length; i++)
                  SettingRow(
                    key: ValueKey('eq-preset-$i'),
                    title: _eqPresetLabels[i],
                    onTap: () => _select(i),
                    // 选中态用 check_circle，未选 radio_button_unchecked——
                    // 避开 Flutter 3.32+ 弃用的 Radio.groupValue/onChanged API。
                    control: Icon(
                      currentIndex == i
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: Tokens.iconSm,
                      color:
                          currentIndex == i
                              ? Tokens.accent
                              : Tokens.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
