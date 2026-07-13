import 'package:flutter/material.dart';

import '../../../kernel/engine/engine_state.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/glass_container.dart';
import '../../shared/animated_section_list.dart';
import '../../shared/section_header.dart';
import '../../shared/settings_card.dart'; // SettingRow export

/// Equalizer settings tab — provides audio frequency presets via FFmpeg filters.
///
/// Applies audio filters through MDK's `af` property via
/// [EngineState.setEqualizer]. The underlying FFmpeg filter chain format is:
/// `filter_name=param1=value1,param2=value2` — multiple filters separated by
/// commas are applied sequentially (e.g., `bass=g=8,treble=g=6`).
///
/// An empty string `''` disables the equalizer, passing original audio through.
///
/// ## Adding a new preset
///
/// 1. Add a filter string to [_presetValues] using FFmpeg equalizer syntax:
///    - `bass=g=N` — boost/cut low frequencies (gain in dB)
///    - `treble=g=N` — boost/cut high frequencies (gain in dB)
///    - Combine with commas: `bass=g=5,treble=g=3`
/// 2. Add a corresponding label in [_presetLabel]
/// 3. The filter chain hot-swaps in real time — no need to re-open the file;
///    MDK reinitializes the audio filter graph on each call
class EqualizerTab extends StatefulWidget {
  final EngineState engine;
  final VoidCallback? onReset;
  const EqualizerTab({super.key, required this.engine, this.onReset});

  @override
  State<EqualizerTab> createState() => _EqualizerTabState();
}

class _EqualizerTabState extends State<EqualizerTab> {
  // FFmpeg 滤镜字符串 — 通过 EngineState.setProperty('af', ...) 设置到 MDK 引擎
  // 增益单位 dB（分贝）：正数增强、负数衰减。建议范围 -20dB ~ +20dB，过高可能导致削波失真
  // 滤镜链热切换：MDK 实时重新初始化音频滤镜图，不需要重新打开文件
  static const _presetValues = [
    '', // 禁用均衡器，原始音频直通
    'bass=g=10', // 增强低频（~60-250Hz），适合流行/嘻哈音乐
    'treble=g=5', // 增强高频（~2kHz-16kHz），适合古典/人声突出
    'bass=g=8,treble=g=6', // 低频增强+高频延伸，摇滚乐典型频响曲线
    'bass=g=3,treble=g=4', // 低频柔和+高频细节，交响乐动态范围保留
  ];

  int _selectedIndex = 0;

  String _presetLabel(int index, AppLocalizations l10n) {
    return switch (index) {
      0 => l10n.eqOff,
      1 => l10n.eqBassBoost,
      2 => l10n.eqVocalBoost,
      3 => l10n.eqRock,
      4 => l10n.eqClassical,
      _ => l10n.eqOff,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedSectionList(
      children: [
        // 均衡器预设 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.equalizer, icon: Icons.equalizer),
              for (int i = 0; i < _presetValues.length; i++)
                SettingRow(
                  title: _presetLabel(i, l10n),
                  control: Icon(
                    i == _selectedIndex
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: i == _selectedIndex
                        ? Tokens.accent
                        : Tokens.textDisabled,
                    size: Tokens.iconLg,
                  ),
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    widget.engine.setEqualizer(_presetValues[i]);
                  },
                ),
            ],
          ),
        ),
        // 重置按钮 — 底部左侧
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: Tokens.spSm),
            child: TextButton(
              onPressed: widget.onReset,
              child: Text(
                l10n.resetToDefaults,
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
