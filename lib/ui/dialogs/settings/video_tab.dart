import 'dart:async';

import 'package:flutter/material.dart';

import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../../kernel/ui/theme/tokens.dart';
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
            _DebouncedSlider(
              notifier: service.brightness,
              label: l10n.brightness,
            ),
            _DebouncedSlider(notifier: service.contrast, label: l10n.contrast),
            _DebouncedSlider(
              notifier: service.saturation,
              label: l10n.saturation,
            ),
            _DebouncedSlider(notifier: service.hue, label: l10n.hue),
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
          children: [_DeinterlaceToggle(notifier: service.deinterlaceEnabled)],
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

class _DebouncedSlider extends StatefulWidget {
  final ValueNotifier<double> notifier;
  final String label;
  const _DebouncedSlider({required this.notifier, required this.label});

  @override
  State<_DebouncedSlider> createState() => _DebouncedSliderState();
}

class _DebouncedSliderState extends State<_DebouncedSlider> {
  bool _dragging = false;
  double _dragValue = 0;
  Timer? _debounce;

  double get _effectiveValue => _dragging ? _dragValue : widget.notifier.value;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.notifier,
      builder: (_, _, _) {
        final display = _effectiveValue;
        return Row(
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
                value: display,
                min: -1.0,
                max: 1.0,
                onChanged: (v) {
                  setState(() {
                    _dragging = true;
                    _dragValue = v;
                  });
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 50),
                    () => widget.notifier.value = v,
                  );
                },
                onChangeEnd: (_) {
                  setState(() => _dragging = false);
                },
                activeColor: Tokens.accent,
                inactiveColor: Tokens.bgHover,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(display * 100).round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Tokens.textTertiary,
                  fontSize: Tokens.fontOverline,
                  fontFeatures: [Tokens.tabularFigures],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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

class _DeinterlaceToggle extends StatelessWidget {
  final ValueNotifier<bool> notifier;
  const _DeinterlaceToggle({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, enabled, _) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.enableDeinterlace,
                    style: const TextStyle(
                      color: Tokens.textPrimary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                  Text(
                    l10n.softwareDecoderOnly,
                    style: const TextStyle(
                      color: Tokens.textTertiary,
                      fontSize: Tokens.fontOverline,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) => notifier.value = v,
              activeThumbColor: Tokens.accent,
            ),
          ],
        );
      },
    );
  }
}
