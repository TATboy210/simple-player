import 'package:flutter/material.dart';

import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// 画面处理 tab — 色彩校正 + 旋转 + 画面比例 + 去隔行
class VideoTab extends StatelessWidget {
  final VideoProcessingService? videoProcessing;
  const VideoTab({super.key, this.videoProcessing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (videoProcessing == null) {
      return Center(
        child: Text(
          l10n.videoProcessingUnavailable,
          style: const TextStyle(color: Tokens.textSecondary),
        ),
      );
    }
    final service = videoProcessing!;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 色彩校正
        SettingsCard(
          title: l10n.brightness,
          icon: Icons.color_lens,
          children: [
            SettingSliderRow(
              label: l10n.brightness,
              notifier: service.brightness,
            ),
            SettingSliderRow(label: l10n.contrast, notifier: service.contrast),
            SettingSliderRow(
              label: l10n.saturation,
              notifier: service.saturation,
            ),
            SettingSliderRow(label: l10n.hue, notifier: service.hue),
          ],
        ),
        // 旋转
        SettingsCard(
          title: l10n.rotation,
          icon: Icons.rotate_right,
          children: [_RotationPicker(notifier: service.rotation)],
        ),
        // 画面比例
        SettingsCard(
          title: l10n.aspectRatio,
          icon: Icons.aspect_ratio,
          children: [_AspectRatioSelector(notifier: service.aspectRatioMode)],
        ),
        // 去隔行
        SettingsCard(
          title: l10n.enableDeinterlace,
          icon: Icons.deblur,
          children: [
            SettingSwitchRow(
              title: l10n.enableDeinterlace,
              description: l10n.softwareDecoderOnly,
              notifier: service.deinterlaceEnabled,
            ),
          ],
        ),
        // 重置
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Tokens.spMd),
            child: InkWell(
              onTap: service.resetAll,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spMd,
                  vertical: Tokens.spXs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Tokens.borderHighlight, width: 1),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: Text(
                  l10n.resetAll,
                  style: const TextStyle(
                    color: Tokens.accent,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 内部控件 ──

class _RotationPicker extends StatelessWidget {
  final ValueNotifier<int> notifier;
  const _RotationPicker({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (_, current, _) {
        return Wrap(
          spacing: Tokens.spSm,
          children: [0, 90, 180, 270].map((deg) {
            final selected = current == deg;
            return ChoiceChip(
              label: Text('$deg°'),
              selected: selected,
              onSelected: (_) => notifier.value = deg,
              selectedColor: Tokens.accent,
              backgroundColor: Tokens.bgElevated,
              labelStyle: TextStyle(
                color: selected ? Tokens.textPrimary : Tokens.textSecondary,
                fontSize: Tokens.fontOverline,
              ),
              side: BorderSide(
                color: selected ? Tokens.accent : Tokens.borderHighlight,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AspectRatioSelector extends StatelessWidget {
  final ValueNotifier<AspectRatioMode> notifier;
  const _AspectRatioSelector({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<AspectRatioMode>(
      valueListenable: notifier,
      builder: (_, current, _) {
        return DropdownButton<AspectRatioMode>(
          value: current,
          isExpanded: true,
          dropdownColor: Tokens.bgElevated,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
          items: AspectRatioMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_label(mode, l10n)),
                ),
              )
              .toList(),
          onChanged: (mode) {
            if (mode != null) notifier.value = mode;
          },
        );
      },
    );
  }

  String _label(AspectRatioMode mode, AppLocalizations l10n) {
    return switch (mode) {
      AspectRatioMode.keepOriginal => l10n.aspectRatioOriginal,
      AspectRatioMode.stretch => l10n.aspectRatioStretch,
      AspectRatioMode.cropFill => l10n.aspectRatioCropFill,
      _ => mode.label,
    };
  }
}
