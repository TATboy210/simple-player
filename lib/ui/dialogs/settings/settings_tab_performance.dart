import 'package:flutter/material.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// 性能设置 tab — D3D11 渲染参数 + 硬件解码开关
///
/// 通过 MediaEngine 接口控制引擎参数，不直接依赖 FvpEngine 实现。
/// 设置通过 SettingsStore 持久化，重启后保持用户选择。
class PerformanceTab extends StatefulWidget {
  final MediaEngine engine;
  const PerformanceTab({super.key, required this.engine});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  late final _D3d11SyncNotifier _d3d11Sync;
  late final _HardwareDecodingNotifier _hardwareDecoding;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final d3d11Sync = await SettingsStore.loadD3d11SyncEnabled();
    final hardwareDecoding = await SettingsStore.loadHardwareDecoding();
    if (!mounted) return;
    setState(() {
      _d3d11Sync = _D3d11SyncNotifier(widget.engine, initialValue: d3d11Sync);
      _hardwareDecoding = _HardwareDecodingNotifier(
        widget.engine,
        initialValue: hardwareDecoding,
      );
      _loading = false;
    });
  }

  @override
  void dispose() {
    if (!_loading) {
      _d3d11Sync.dispose();
      _hardwareDecoding.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // D3D11 渲染
        SettingsCard(
          title: l10n.d3d11Rendering,
          icon: Icons.speed,
          children: [
            SettingSwitchRow(
              title: l10n.d3d11Sync,
              description: l10n.d3d11SyncDesc,
              notifier: _d3d11Sync,
            ),
          ],
        ),
        // 解码器
        SettingsCard(
          title: l10n.decoderSettings,
          icon: Icons.memory,
          children: [
            SettingSwitchRow(
              title: l10n.hardwareDecoding,
              description: l10n.hardwareDecodingDesc,
              notifier: _hardwareDecoding,
            ),
          ],
        ),
        // 提示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.spLg),
          child: Text(
            l10n.performanceHint,
            style: const TextStyle(
              color: Tokens.textTertiary,
              fontSize: Tokens.fontOverline,
            ),
          ),
        ),
      ],
    );
  }
}

/// D3D11 同步开关 — 桥接 MediaEngine.setD3d11SyncEnabled 到 `ValueNotifier<bool>`
///
/// 默认开启（同步模式），关闭后切换到异步模式（低延迟，可能撕裂）。
/// 切换时通过 SettingsStore 持久化，重启后保持用户选择。
class _D3d11SyncNotifier extends ValueNotifier<bool> {
  final MediaEngine _engine;

  _D3d11SyncNotifier(this._engine, {required bool initialValue})
      : super(initialValue);

  @override
  set value(bool newValue) {
    SettingsStore.saveD3d11SyncEnabled(newValue);
    _engine.setD3d11SyncEnabled(newValue);
    super.value = newValue;
  }
}

/// 硬件解码开关 — 桥接 MediaEngine.setHardwareDecoding 到 `ValueNotifier<bool>`
///
/// 默认开启（硬件解码优先），关闭后回退到软件解码。
/// 切换时通过 SettingsStore 持久化，重启后保持用户选择。
class _HardwareDecodingNotifier extends ValueNotifier<bool> {
  final MediaEngine _engine;

  _HardwareDecodingNotifier(this._engine, {required bool initialValue})
      : super(initialValue);

  @override
  set value(bool newValue) {
    SettingsStore.saveHardwareDecoding(newValue);
    _engine.setHardwareDecoding(newValue);
    super.value = newValue;
  }
}
