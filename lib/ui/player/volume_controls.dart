import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../shared/value_listenable_builder2.dart';
import '../shared/osd_overlay.dart';

/// 音量按钮（单击静音）
class VolumeButton extends StatefulWidget {
  final EngineState engine;

  const VolumeButton({super.key, required this.engine});

  @override
  State<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<VolumeButton> {
  double _savedVolume = 1.0;

  void _toggleMute() {
    final engine = widget.engine;
    final l10n = AppLocalizations.of(context);
    if (engine.isMuted.value) {
      engine.setMute(false);
      engine.setVolume(_savedVolume);
      OsdService.I.show(
        '${(_savedVolume * 100).round()}%',
        progress: _savedVolume,
      );
    } else {
      _savedVolume = engine.volume.value;
      engine.setVolume(0);
      engine.setMute(true);
      OsdService.I.show(l10n.mute, icon: Icons.volume_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder2<bool, double>(
      first: widget.engine.isMuted,
      second: widget.engine.volume,
      builder: (_, muted, volume, _) {
        IconData icon;
        if (muted || volume == 0) {
          icon = Icons.volume_off;
        } else if (volume < 0.5) {
          icon = Icons.volume_down;
        } else {
          icon = Icons.volume_up;
        }
        return GlassButton.iconOnly(
          icon: icon,
          iconSize: Tokens.iconLg,
          color: muted ? Tokens.accent : Tokens.textPrimary,
          onPressed: _toggleMute,
          tooltip: muted ? l10n.unmute : l10n.mute,
        );
      },
    );
  }
}

/// 音量滑块（内联水平条）
class VolumeSlider extends StatelessWidget {
  static const _sliderTheme = SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
  );

  final EngineState engine;

  const VolumeSlider({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Tokens.volumeSliderWidth,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
            final v = (engine.volume.value + delta).clamp(0.0, 1.0);
            engine.setVolume(v);
            OsdService.I.show('${(v * 100).round()}%', progress: v);
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: engine.volume,
          builder: (_, volume, _) => SliderTheme(
            data: _sliderTheme,
            child: Slider(
              value: volume,
              onChanged: (v) {
                engine.setVolume(v);
                OsdService.I.show('${(v * 100).round()}%', progress: v);
              },
              activeColor: Tokens.accent,
              inactiveColor: Tokens.bgHover,
            ),
          ),
        ),
      ),
    );
  }
}
