import 'package:flutter/material.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// 性能设置 tab — D3D11 渲染参数 + 硬件解码开关
///
/// 通过 MediaEngine 接口控制引擎参数，不直接依赖 FvpEngine 实现。
class PerformanceTab extends StatelessWidget {
  final MediaEngine engine;
  const PerformanceTab({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
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
              notifier: _D3d11SyncNotifier(engine),
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
              notifier: _HardwareDecodingNotifier(engine),
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
class _D3d11SyncNotifier extends ValueNotifier<bool> {
  final MediaEngine _engine;

  _D3d11SyncNotifier(this._engine) : super(true); // 默认同步

  @override
  set value(bool newValue) {
    _engine.setD3d11SyncEnabled(newValue);
    super.value = newValue;
  }
}

/// 硬件解码开关 — 桥接 MediaEngine.setHardwareDecoding 到 `ValueNotifier<bool>`
///
/// 默认开启（硬件解码优先），关闭后回退到软件解码。
class _HardwareDecodingNotifier extends ValueNotifier<bool> {
  final MediaEngine _engine;

  _HardwareDecodingNotifier(this._engine) : super(true); // 默认硬件解码

  @override
  set value(bool newValue) {
    _engine.setHardwareDecoding(newValue);
    super.value = newValue;
  }
}
