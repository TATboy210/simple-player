import 'dart:async';

import 'package:flutter/material.dart';

import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../features/player/services/video_processing_service.dart';
import '../../../features/player/models/video_processing_state.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// Video processing tab — color correction, rotation, aspect ratio, and deinterlace.
///
/// Uses a single `ValueListenableBuilder<VideoProcessingState>` to listen to all
/// properties via [VideoProcessingService]. Each color correction parameter:
/// - brightness: 亮度调整，范围 -1.0 到 1.0，0.0 = 无变化
/// - contrast: 对比度调整，范围 -1.0 到 1.0，0.0 = 无变化
/// - saturation: 饱和度调整，范围 -1.0 到 1.0，0.0 = 无变化
/// - hue: 色调调整，范围 -180 到 180 度，0.0 = 无变化
///
/// Rotation is limited to hardware steps: 0°, 90°, 180°, 270°.
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
    return ValueListenableBuilder<VideoProcessingState>(
      valueListenable: service.state,
      builder: (_, s, _) => ListView(
        padding: EdgeInsets.zero,
        children: [
          // 色彩校正
          SettingsCard(
            title: l10n.brightness,
            icon: Icons.color_lens,
            children: [
              _VideoSlider(
                label: l10n.brightness,
                value: s.brightness,
                onChanged: service.updateBrightness,
              ),
              _VideoSlider(
                label: l10n.contrast,
                value: s.contrast,
                onChanged: service.updateContrast,
              ),
              _VideoSlider(
                label: l10n.saturation,
                value: s.saturation,
                onChanged: service.updateSaturation,
              ),
              _VideoSlider(
                label: l10n.hue,
                value: s.hue,
                onChanged: service.updateHue,
              ),
            ],
          ),
          // 旋转
          SettingsCard(
            title: l10n.rotation,
            icon: Icons.rotate_right,
            children: [
              _RotationPicker(
                value: s.rotation,
                onChanged: service.updateRotation,
              ),
            ],
          ),
          // 画面比例
          SettingsCard(
            title: l10n.aspectRatio,
            icon: Icons.aspect_ratio,
            children: [
              _AspectRatioSelector(
                value: s.aspectRatioMode,
                onChanged: service.updateAspectRatio,
              ),
            ],
          ),
          // 去隔行
          SettingsCard(
            title: l10n.enableDeinterlace,
            icon: Icons.deblur,
            children: [
              SettingSwitchRow(
                title: l10n.enableDeinterlace,
                description: l10n.softwareDecoderOnly,
                notifier: _BoolNotifier.fromState(
                  s.deinterlaceEnabled,
                  service.updateDeinterlace,
                ),
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
      ),
    );
  }
}

// ── 内部控件 ──

/// 视频滑块 — 直接接受 value + onChanged，无需 ValueNotifier
class _VideoSlider extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _VideoSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_VideoSlider> createState() => _VideoSliderState();
}

class _VideoSliderState extends State<_VideoSlider> {
  bool _hovered = false;
  bool _dragging = false;
  double _dragValue = 0;
  Timer? _debounce;

  double get _effectiveValue => _dragging ? _dragValue : widget.value;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        height: Tokens.sliderHeight,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
        decoration: BoxDecoration(
          color: _hovered ? Tokens.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: Tokens.sliderLabelWidth,
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
                value: _effectiveValue,
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
                    () => widget.onChanged(v),
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
              width: Tokens.sliderValueWidth,
              child: Text(
                '${(_effectiveValue * 100).round()}',
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

class _RotationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RotationPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Tokens.spSm,
      children: [0, 90, 180, 270].map((deg) {
        final selected = value == deg;
        return ChoiceChip(
          label: Text('$deg°'),
          selected: selected,
          onSelected: (_) => onChanged(deg),
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
  }
}

class _AspectRatioSelector extends StatelessWidget {
  final AspectRatioMode value;
  final ValueChanged<AspectRatioMode> onChanged;
  const _AspectRatioSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButton<AspectRatioMode>(
      value: value,
      isExpanded: true,
      dropdownColor: Tokens.bgElevated,
      style: const TextStyle(
        color: Tokens.textPrimary,
        fontSize: Tokens.fontCaption,
      ),
      items: AspectRatioMode.values
          .map(
            (mode) =>
                DropdownMenuItem(value: mode, child: Text(_label(mode, l10n))),
          )
          .toList(),
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
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

/// 轻量 BoolNotifier — 桥接 bool 值到 SettingSwitchRow 的 `ValueNotifier<bool>` 接口
///
/// 仅在 VideoTab 内部使用，不持有状态（值来自 VideoProcessingState）。
class _BoolNotifier extends ValueNotifier<bool> {
  final void Function(bool) _onChanged;

  _BoolNotifier._(super.value, this._onChanged);

  factory _BoolNotifier.fromState(bool value, void Function(bool) onChanged) =>
      _BoolNotifier._(value, onChanged);

  @override
  set value(bool newValue) {
    _onChanged(newValue);
    super.value = newValue;
  }
}
