import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/services/video_processing_service.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_dialog.dart';
import '../widgets/video_processing_tab.dart';

class SettingsDialog extends StatefulWidget {
  final MediaEngine engine;
  final VideoProcessingService? videoProcessing;

  const SettingsDialog({
    super.key,
    required this.engine,
    this.videoProcessing,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.settings,
      width: 400,
      height: 420,
      content: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Tokens.accent,
            unselectedLabelColor: Tokens.textSecondary,
            indicatorColor: Tokens.accent,
            tabs: [
              Tab(text: l10n.equalizer),
              Tab(text: l10n.audioTrack),
              Tab(text: l10n.videoProcessing),
            ],
          ),
          const SizedBox(height: Tokens.spSm),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EqualizerTab(engine: widget.engine),
                _AudioTrackTab(engine: widget.engine),
                widget.videoProcessing != null
                    ? VideoProcessingTab(service: widget.videoProcessing!)
                    : Center(
                        child: Text(
                          l10n.noAudioTracks,
                          style: const TextStyle(color: Tokens.textSecondary),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerTab extends StatefulWidget {
  final MediaEngine engine;
  const _EqualizerTab({required this.engine});

  @override
  State<_EqualizerTab> createState() => _EqualizerTabState();
}

class _EqualizerTabState extends State<_EqualizerTab> {
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
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? Tokens.accent : Tokens.textDisabled,
            size: Tokens.iconLg,
          ),
          title: Text(
            _presetLabel(i, l10n),
            style: const TextStyle(color: Tokens.textPrimary, fontSize: Tokens.fontCaption),
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

class _AudioTrackTab extends StatelessWidget {
  final MediaEngine engine;
  const _AudioTrackTab({required this.engine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tracks = engine.getAudioTracks();
    if (tracks.isEmpty) {
      return Center(
        child: Text(l10n.noAudioTracks, style: const TextStyle(color: Tokens.textSecondary)),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final track = tracks[i];
        final active = engine.activeAudioTracks.contains(i);
        final label = track.codec.isEmpty
            ? l10n.audioTrackN(i + 1)
            : '${track.codec} (${track.channels}ch)';
        return ListTile(
          leading: Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? Tokens.accent : Tokens.textDisabled,
            size: Tokens.iconLg,
          ),
          title: Text(label, style: const TextStyle(color: Tokens.textPrimary, fontSize: Tokens.fontCaption)),
          subtitle: track.language.isNotEmpty
              ? Text(track.language, style: const TextStyle(color: Tokens.textSecondary, fontSize: Tokens.fontOverline))
              : null,
          onTap: () {
            engine.switchAudioTrack(i);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
