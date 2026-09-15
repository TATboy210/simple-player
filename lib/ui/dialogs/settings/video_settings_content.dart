/// 「视频」分区内容 (v0.0.6) — 亮度/对比度/饱和度/色调滑条 + 旋转 +
/// 宽高比 + 去隔行 + 硬解 + 重置。
///
/// 数据通道: 滑条经 [VideoProcessingService] (diff 同步引擎), 硬解经
/// [AppSettingsService] (引擎 + 落盘)。引擎侧经 mpv 属性落地, 状态
/// file-scoped 自动跨文件重放 — UI 无感知。
library;

import 'package:flutter/material.dart';

import '../../../features/player/models/video_processing_state.dart';
import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/services/app_settings_service.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/setting_slider_row.dart';
import '../../shared/spin_control.dart';
import '../../theme/tokens.dart';

/// 「视频」分区内容.
class VideoSettingsContent extends StatefulWidget {
  const VideoSettingsContent({
    super.key,
    required this.videoProcessing,
    this.settings,
  });

  final VideoProcessingService videoProcessing;

  /// 硬解开关通道 — null 时硬解行隐藏（纯视频处理仍可用）.
  final AppSettingsService? settings;

  @override
  State<VideoSettingsContent> createState() => _VideoSettingsContentState();
}

class _VideoSettingsContentState extends State<VideoSettingsContent> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Tokens.spLg),
      child: SingleChildScrollView(
        child: ValueListenableBuilder<VideoProcessingState>(
          valueListenable: widget.videoProcessing.state,
          builder: (context, state, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Tokens.spXs,
            children: [
              _BoundSlider(
                label: l10n.brightness,
                service: widget.videoProcessing,
                read: (s) => s.brightness,
                write: (v) => widget.videoProcessing.updateBrightness(v),
              ),
              _BoundSlider(
                label: l10n.contrast,
                service: widget.videoProcessing,
                read: (s) => s.contrast,
                write: (v) => widget.videoProcessing.updateContrast(v),
              ),
              _BoundSlider(
                label: l10n.saturation,
                service: widget.videoProcessing,
                read: (s) => s.saturation,
                write: (v) => widget.videoProcessing.updateSaturation(v),
              ),
              _BoundSlider(
                label: l10n.hue,
                service: widget.videoProcessing,
                read: (s) => s.hue,
                write: (v) => widget.videoProcessing.updateHue(v),
              ),
              const SizedBox(height: Tokens.spSm),
              _buildRotationRow(l10n, state),
              _buildAspectRatioRow(l10n, state),
              _buildSwitchRow(
                label: l10n.enableDeinterlace,
                value: state.deinterlaceEnabled,
                onChanged: (v) => widget.videoProcessing.updateDeinterlace(v),
              ),
              if (widget.settings != null)
                _buildHardwareDecodingRow(l10n),
              const SizedBox(height: Tokens.spSm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => widget.videoProcessing.resetAll(),
                  child: Text(
                    l10n.resetAll,
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 旋转行 — 0/90/180/270 四段 SpinControl (mpv video-rotate).
  Widget _buildRotationRow(AppLocalizations l10n, VideoProcessingState state) {
    const degrees = <int>[0, 90, 180, 270];
    final index = degrees.indexOf(state.rotation).clamp(0, degrees.length - 1);
    return _SettingNavRow(
      label: l10n.rotation,
      child: SpinControl(
        options: [for (final d in degrees) '$d'],
        currentIndex: index,
        onChanged: (i) => widget.videoProcessing.updateRotation(degrees[i]),
      ),
    );
  }

  /// 宽高比行 — 六模式 SpinControl (stretch/cropFill 引擎侧诚实降级).
  Widget _buildAspectRatioRow(
    AppLocalizations l10n,
    VideoProcessingState state,
  ) {
    final modes = AspectRatioMode.values;
    final index = modes.indexOf(state.aspectRatioMode).clamp(
          0,
          modes.length - 1,
        );
    return _SettingNavRow(
      label: l10n.aspectRatio,
      child: SpinControl(
        options: [for (final m in modes) m.name],
        currentIndex: index,
        formatValue: (raw) => _aspectLabel(l10n, raw),
        onChanged: (i) => widget.videoProcessing.updateAspectRatio(modes[i]),
      ),
    );
  }

  /// 宽高比模式显示名 — 枚举 name → 本地化标签 (比率字符串语言无关).
  static String _aspectLabel(AppLocalizations l10n, String raw) =>
      switch (AspectRatioMode.values.firstWhere((m) => m.name == raw)) {
        AspectRatioMode.keepOriginal => l10n.aspectRatioOriginal,
        AspectRatioMode.stretch => l10n.aspectRatioStretch,
        AspectRatioMode.cropFill => l10n.aspectRatioCropFill,
        AspectRatioMode.ratio4_3 => '4:3',
        AspectRatioMode.ratio16_9 => '16:9',
        AspectRatioMode.ratio21_9 => '21:9',
      };

  /// 硬解行 — AppSettingsService 通道 (mpv hwdec + 落盘).
  Widget _buildHardwareDecodingRow(AppLocalizations l10n) {
    final settings = widget.settings!;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.hardwareDecoding,
      builder: (context, enabled, _) => _buildSwitchRow(
        label: l10n.hardwareDecoding,
        value: enabled,
        onChanged: settings.setHardwareDecoding,
      ),
    );
  }

  /// 通用开关行 — 行本体点击与 Switch 均可切换.
  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _SettingNavRow(
      label: label,
      onTap: () => onChanged(!value),
      child: Switch(
        value: value,
        // activeColor 已废弃 (Flutter 3.31+) — 用 activeThumbColor.
        activeThumbColor: Tokens.accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// 绑定滑条 — SettingSliderRow 的 ValueNotifier 与 VideoProcessingService
/// 单一状态对象双向同步: service 状态变化 → 本地 notifier (外部重放/
/// 重置场景); 本地 notifier 变化 (拖动防抖后) → update* 写入.
class _BoundSlider extends StatefulWidget {
  const _BoundSlider({
    required this.label,
    required this.service,
    required this.read,
    required this.write,
  });

  final String label;
  final VideoProcessingService service;
  final double Function(VideoProcessingState) read;
  final ValueChanged<double> write;

  @override
  State<_BoundSlider> createState() => _BoundSliderState();
}

class _BoundSliderState extends State<_BoundSlider> {
  late final ValueNotifier<double> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<double>(widget.read(widget.service.state.value));
    widget.service.state.addListener(_syncFromService);
    _notifier.addListener(_writeToService);
  }

  /// service → 本地 (重置/持久回放等外部状态变化).
  void _syncFromService() {
    final value = widget.read(widget.service.state.value);
    if (_notifier.value != value) _notifier.value = value;
  }

  /// 本地 → service (拖动). 值相同 no-op 防回环.
  void _writeToService() => widget.write(_notifier.value);

  @override
  void dispose() {
    widget.service.state.removeListener(_syncFromService);
    _notifier.removeListener(_writeToService);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingSliderRow(
      label: widget.label,
      notifier: _notifier,
      min: -1.0,
      max: 1.0,
    );
  }
}

/// 设置导航行骨架 — label + 右侧控件 (本地复刻 general 的 _SettingsRow,
/// 因后者为私有类; hover 高亮同 token).
class _SettingNavRow extends StatefulWidget {
  const _SettingNavRow({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_SettingNavRow> createState() => _SettingNavRowState();
}

class _SettingNavRowState extends State<_SettingNavRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: Tokens.durationFast),
          padding: const EdgeInsets.symmetric(
            vertical: 3,
            horizontal: Tokens.spSm,
          ),
          decoration: BoxDecoration(
            color: _hovered ? Tokens.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
