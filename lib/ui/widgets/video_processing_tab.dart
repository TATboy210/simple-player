import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/models/aspect_ratio_mode.dart';
import '../../kernel/services/video_processing_service.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

class VideoProcessingTab extends StatelessWidget {
  final VideoProcessingService service;

  const VideoProcessingTab({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
      children: [
        _DebouncedSlider(notifier: service.brightness, label: l10n.brightness),
        _DebouncedSlider(notifier: service.contrast, label: l10n.contrast),
        _DebouncedSlider(notifier: service.saturation, label: l10n.saturation),
        _DebouncedSlider(notifier: service.hue, label: l10n.hue),
        const SizedBox(height: Tokens.spMd),
        _SectionLabel(l10n.rotation),
        _RotationPicker(notifier: service.rotation),
        const SizedBox(height: Tokens.spMd),
        _SectionLabel(l10n.aspectRatio),
        _AspectRatioSelector(notifier: service.aspectRatioMode),
        const SizedBox(height: Tokens.spMd),
        _DeinterlaceToggle(notifier: service.deinterlaceEnabled),
        const SizedBox(height: Tokens.spMd),
        Center(
          child: TextButton(
            onPressed: service.resetAll,
            child: Text(l10n.resetAll, style: const TextStyle(color: Tokens.accent, fontSize: Tokens.fontCaption)),
          ),
        ),
        const SizedBox(height: Tokens.spSm),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spSm),
      child: Text(text, style: const TextStyle(color: Tokens.textSecondary, fontSize: Tokens.fontCaption, fontWeight: FontWeight.w600)),
    );
  }
}

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
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.notifier,
      builder: (_, __, ___) {
        final display = _effectiveValue;
        return Row(
          children: [
            SizedBox(width: 64, child: Text(widget.label, style: const TextStyle(color: Tokens.textSecondary, fontSize: Tokens.fontOverline))),
            Expanded(
              child: Slider(
                value: display,
                min: -1.0,
                max: 1.0,
                onChanged: (v) {
                  setState(() { _dragging = true; _dragValue = v; });
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 50), () => widget.notifier.value = v);
                },
                onChangeEnd: (_) { setState(() => _dragging = false); },
                activeColor: Tokens.accent,
                inactiveColor: Tokens.bgHover,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text('\${(display * 100).round()}', textAlign: TextAlign.right, style: const TextStyle(color: Tokens.textTertiary, fontSize: Tokens.fontOverline, fontFeatures: [Tokens.tabularFigures])),
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
              label: Text('\$deg°'),
              selected: selected,
              onSelected: (_) => notifier.value = deg,
              selectedColor: Tokens.accent,
              backgroundColor: Tokens.bgElevated,
              labelStyle: TextStyle(color: selected ? Tokens.textPrimary : Tokens.textSecondary, fontSize: Tokens.fontOverline),
              side: BorderSide(color: selected ? Tokens.accent : Tokens.borderHighlight),
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
          style: const TextStyle(color: Tokens.textPrimary, fontSize: Tokens.fontCaption),
          items: AspectRatioMode.values.map((mode) => DropdownMenuItem(value: mode, child: Text(_label(mode, l10n)))).toList(),
          onChanged: (mode) { if (mode != null) notifier.value = mode; },
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
                  Text(l10n.enableDeinterlace, style: const TextStyle(color: Tokens.textPrimary, fontSize: Tokens.fontCaption)),
                  Text(l10n.softwareDecoderOnly, style: const TextStyle(color: Tokens.textTertiary, fontSize: Tokens.fontOverline)),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: (v) => notifier.value = v, activeColor: Tokens.accent),
          ],
        );
      },
    );
  }
}
