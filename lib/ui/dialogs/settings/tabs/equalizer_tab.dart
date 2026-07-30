// EqualizerTab — 音频设置首 tab（Phase 33）：EQ 预设 + balance + 音频延迟。
//
// 三个延迟应用控制：
// - EQ 预设（5 选 1）：pending('eqPresetIndex')
// - 平衡滑块 [-1.0..1.0]：pending('balance')（负=偏左，0=居中，正=偏右）
// - 音频延迟滑块 [0..10000ms]：pending('syncMs')（正值=音频延后，FFmpeg adelay
//   无法提前音频，故 UI 正值统一表示"音频延后"——见 AudioFilterCompositor）
//
// 所有控制经 pending.update 延迟存储，Apply/OK 时由
// SettingsPanelController.commitPending() 构造 AudioSettings 快照交回调。
// 不直接调 service——纯 UI 投影 pending 状态（AUDIO-06 延迟应用）。
//
// EQ 预设索引与 AudioFilterCompositor.eqPresets 表一一对应（0..4）；组合器内部
// 对索引额外 clamp 作纵深防御，故两处解耦安全。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 音频设置首 tab（Phase 33）。
///
/// 三个延迟应用控制——EQ 预设 / balance / 音频延迟——选择经
/// [PendingSettingsState.update] 延迟存储，不直接调引擎。组合器在
/// [AudioFilterCompositor] 中定义，此处仅持有本地化标签与滑块范围。
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

  /// 当前 balance [-1.0..1.0]——从 pending 投影；非 double 回退 0.0（居中）。
  double get _currentBalance {
    final v = widget.pending.current('balance');
    if (v is double) return v;
    return 0.0;
  }

  /// 当前音频延迟毫秒 [0..10000]——从 pending 投影；非 int 回退 0（无延迟）。
  int get _currentSync {
    final v = widget.pending.current('syncMs');
    if (v is int) return v;
    return 0;
  }

  /// 当前音量标准化开关——从 pending 投影；非 bool 回退 false（关闭）。
  ///
  /// Phase 33 Wave 3（AUDIO-04）：normalization 经 dynaudnorm 段应用，
  /// false 时组合器省略该段（见 AudioFilterCompositor._appendDynaudnorm）。
  bool get _currentNormalization {
    final v = widget.pending.current('normalization');
    if (v is bool) return v;
    return false;
  }

  /// 选择预设——写入 pending 并触发本 widget 重建。
  ///
  /// pending 是纯数据容器（非 Listenable），故需手动 setState 刷新 radio 显示；
  /// 真正的引擎应用延迟到 Apply/OK 提交时（AUDIO-06）。
  void _select(int index) {
    widget.pending.update('eqPresetIndex', index);
    setState(() {});
  }

  /// balance 滑块变更——写 pending 并重建以刷新数值显示。
  void _onBalanceChanged(double v) {
    widget.pending.update('balance', v);
    setState(() {});
  }

  /// 音频延迟滑块变更——四舍五入为整毫秒写 pending 并重建。
  void _onSyncChanged(double v) {
    widget.pending.update('syncMs', v.round());
    setState(() {});
  }

  /// 音量标准化开关变更——只写 pending 并重建（AUDIO-06 延迟应用）。
  ///
  /// 不触达 commit 回调 / engine；Apply/OK 时由 commitPending 构造快照交回调。
  void _onNormalizationChanged(bool value) {
    widget.pending.update('normalization', value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AnimatedSectionList(
        children: [
          _buildEqSection(),
          _buildSpatialSyncSection(),
          _buildNormalizationSection(),
        ],
      ),
    );
  }

  /// EQ 预设选择区——5 个 radio 行。
  Widget _buildEqSection() {
    final currentIndex = _currentIndex;
    return GlassContainer(
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
                color: currentIndex == i ? Tokens.accent : Tokens.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  /// 空间与同步区——balance + 音频延迟滑块（Phase 33 Wave 2）。
  Widget _buildSpatialSyncSection() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spLg,
        vertical: Tokens.spMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '空间与同步', icon: Icons.tune),
          _PendingSliderRow(
            sliderKey: const ValueKey('audio-balance-slider'),
            label: '平衡',
            value: _currentBalance,
            min: -1.0,
            max: 1.0,
            // 显示为 -100..100 百分比（负=偏左，正=偏右）
            formatValue: (v) => '${(v * 100).round()}',
            onChanged: _onBalanceChanged,
          ),
          _PendingSliderRow(
            sliderKey: const ValueKey('audio-sync-slider'),
            label: '音频延迟',
            value: _currentSync.toDouble(),
            min: 0.0,
            max: 10000.0,
            // 显示为整毫秒；正值=音频延后（FFmpeg adelay 无法提前音频）
            formatValue: (v) => '${v.round()}ms',
            onChanged: _onSyncChanged,
          ),
        ],
      ),
    );
  }

  /// 音量标准化区——dynaudnorm 开关（Phase 33 Wave 3，AUDIO-04）。
  ///
  /// 独立 GlassContainer 区段：标准化是动态范围处理，与"空间与同步"概念
  /// 分离。Switch 仅写 pending('normalization')，Apply/OK 才进 af 链。
  Widget _buildNormalizationSection() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spLg,
        vertical: Tokens.spMd,
      ),
      margin: const EdgeInsets.only(top: Tokens.spMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '音量标准化', icon: Icons.graphic_eq),
          SettingRow(
            title: '音量标准化',
            description: '动态范围归一化，平滑音量波动',
            control: Switch(
              key: const ValueKey('audio-normalization-switch'),
              value: _currentNormalization,
              onChanged: _onNormalizationChanged,
              activeThumbColor: Tokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 延迟应用滑块行——label + Slider + 数值显示，绑定 [PendingSettingsState]。
///
/// 仿 [SettingSliderRow] 布局（42 高 + hover bgHover + Tokens.accent），但
/// 数据源是 pending map（非 ValueNotifier）：value 由父 widget 投影并注入，
/// [onChanged] 由父调 `pending.update` + `setState` 重建。hover 态本地持有
/// 以避免父重建影响交互反馈。
///
/// 不持有 commit 回调——滑块只写 pending，Apply/OK 才触发提交（AUDIO-06）。
class _PendingSliderRow extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;

  /// 值→显示文本格式化器（balance 显示百分比、sync 显示毫秒）。
  final String Function(double) formatValue;

  /// 滑块变更回调——父级负责 `pending.update` + `setState`。
  final ValueChanged<double> onChanged;

  /// 稳定标识——供 widget 测试定位。
  final Key sliderKey;

  const _PendingSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
    required this.onChanged,
    required this.sliderKey,
  });

  @override
  State<_PendingSliderRow> createState() => _PendingSliderRowState();
}

class _PendingSliderRowState extends State<_PendingSliderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
        decoration: BoxDecoration(
          color: _hovered ? Tokens.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontOverline,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                key: widget.sliderKey,
                // clamp 纵深防御：pending 残留超界值时不触发 Slider assert
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                onChanged: widget.onChanged,
                activeColor: Tokens.accent,
                inactiveColor: Tokens.bgHover,
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                widget.formatValue(widget.value),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Tokens.textTertiary,
                  fontSize: Tokens.fontOverline,
                  fontFeatures: [Tokens.tabularFigures],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
