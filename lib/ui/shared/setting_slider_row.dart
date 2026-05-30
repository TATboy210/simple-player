import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 滑块设置行 — label + slider + 数值显示，带防抖
///
/// ```dart
/// SettingSliderRow(
///   label: '亮度',
///   notifier: brightnessNotifier,
///   min: -1.0,
///   max: 1.0,
/// )
/// ```
class SettingSliderRow extends StatefulWidget {
  final String label;
  final ValueNotifier<double> notifier;
  final double min;
  final double max;
  final int displayMultiplier;
  final String? displaySuffix;
  final Duration debounceDuration;

  const SettingSliderRow({
    super.key,
    required this.label,
    required this.notifier,
    this.min = -1.0,
    this.max = 1.0,
    this.displayMultiplier = 100,
    this.displaySuffix,
    this.debounceDuration = const Duration(milliseconds: 50),
  });

  @override
  State<SettingSliderRow> createState() => _SettingSliderRowState();
}

class _SettingSliderRowState extends State<SettingSliderRow> {
  bool _hovered = false;
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
        child: ValueListenableBuilder<double>(
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
                    min: widget.min,
                    max: widget.max,
                    onChanged: (v) {
                      setState(() {
                        _dragging = true;
                        _dragValue = v;
                      });
                      _debounce?.cancel();
                      _debounce = Timer(widget.debounceDuration, () {
                        widget.notifier.value = v;
                      });
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
                    '${(display * widget.displayMultiplier).round()}'
                    '${widget.displaySuffix ?? ''}',
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
        ),
      ),
    );
  }
}
