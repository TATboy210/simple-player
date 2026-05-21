import 'package:flutter/material.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/ui/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// 均衡器设置 tab — 5 个预设模式
class EqualizerTab extends StatefulWidget {
  final MediaEngine engine;
  const EqualizerTab({super.key, required this.engine});

  @override
  State<EqualizerTab> createState() => _EqualizerTabState();
}

class _EqualizerTabState extends State<EqualizerTab> {
  static const _presetValues = [
    '',
    'bass=g=10',
    'treble=g=5',
    'bass=g=8,treble=g=6',
    'bass=g=3,treble=g=4',
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
    return ListView.builder(
      itemCount: _presetValues.length,
      itemBuilder: (_, i) {
        final selected = i == _selectedIndex;
        return ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? Tokens.accent : Tokens.textDisabled,
            size: Tokens.iconLg,
          ),
          title: Text(
            _presetLabel(i, l10n),
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
            ),
          ),
          onTap: () {
            setState(() => _selectedIndex = i);
            widget.engine.setEqualizer(_presetValues[i]);
          },
        );
      },
    );
  }
}
