/// 「音频」分区内容 (v0.0.6) — 音频延迟 / 字幕延迟 (毫秒级 SpinControl).
///
/// 写入通道: [AppSettingsService] — 引擎 (mpv audio-delay/sub-delay) +
/// 落盘; file-scoped 属性随新文件装载自动重放, 跨文件保持.
/// EQ 不在本期范围 (v0.0.6 用户裁决)。
library;

import 'package:flutter/material.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/spin_control.dart';
import '../../theme/tokens.dart';

/// 延迟可调范围 (毫秒) 与步长 — ±1s / 50ms 步进, 覆盖常见音画偏移场景.
const _delayMinMs = -1000;
const _delayMaxMs = 1000;
const _delayStepMs = 50;

/// 「音频」分区内容 — StatefulWidget: SpinControl 值非响应式 (箭头驱动),
/// onChanged 里 service 写入后 setState 重建读取最新延迟.
class AudioSettingsContent extends StatefulWidget {
  const AudioSettingsContent({super.key, required this.settings});

  final AppSettingsService settings;

  @override
  State<AudioSettingsContent> createState() => _AudioSettingsContentState();
}

class _AudioSettingsContentState extends State<AudioSettingsContent> {
  /// 延迟毫秒 → SpinControl 索引 (双向线性映射).
  int _msToIndex(int ms) => ((ms - _delayMinMs) ~/ _delayStepMs).clamp(
    0,
    _optionCount - 1,
  );

  /// SpinControl 索引 → 延迟毫秒.
  int _indexToMs(int index) => _delayMinMs + index * _delayStepMs;

  static const _optionCount =
      ((_delayMaxMs - _delayMinMs) ~/ _delayStepMs) + 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = widget.settings;
    final options = [
      for (var i = 0; i < _optionCount; i++) '${_indexToMs(i)}',
    ];

    return Padding(
      padding: const EdgeInsets.all(Tokens.spLg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Tokens.spXs,
          children: [
            _DelayRow(
              label: l10n.audioDelay,
              options: options,
              currentIndex: _msToIndex(settings.audioDelayMs),
              formatValue: (raw) => '$raw ms',
              onChanged: (i) => setState(() {
                settings.setAudioDelayMs(_indexToMs(i));
              }),
            ),
            _DelayRow(
              label: l10n.subtitleDelay,
              options: options,
              currentIndex: _msToIndex(settings.subtitleDelayMs),
              formatValue: (raw) => '$raw ms',
              onChanged: (i) => setState(() {
                settings.setSubtitleDelayMs(_indexToMs(i));
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// 延迟设置行 — label + SpinControl.
class _DelayRow extends StatelessWidget {
  const _DelayRow({
    required this.label,
    required this.options,
    required this.currentIndex,
    required this.formatValue,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final int currentIndex;
  final String Function(String) formatValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        padding: const EdgeInsets.symmetric(
          vertical: 3,
          horizontal: Tokens.spSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
            SpinControl(
              options: options,
              currentIndex: currentIndex,
              formatValue: formatValue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
