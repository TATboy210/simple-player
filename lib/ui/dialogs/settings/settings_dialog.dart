import 'package:flutter/material.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/app_dialog.dart';
import '../../theme/tokens.dart';
import 'about_content.dart';
import 'audio_settings_content.dart';
import 'general_settings_content.dart';
import 'video_settings_content.dart';

/// 设置分区 —— 左侧导航的四个条目。
enum _SettingsTab { general, video, audio, about }

/// 设置页可注入的服务集合 — null 成员时对应分区灰显（向后兼容：
/// 既有测试零注入仍可用，video/audio 维持占位）。
///
/// Explicit bundle over InheritedWidget/单例: 单点消费过重, 全局单例与
/// PlayerServices 生命周期所有权冲突。
class SettingsServicesBundle {
  const SettingsServicesBundle({this.videoProcessing, this.settings});

  /// 视频处理服务 — video 分区的数据源与写入通道.
  final VideoProcessingService? videoProcessing;

  /// 应用偏好编排服务 — audio 分区写入通道 + general 断点开关.
  final AppSettingsService? settings;
}

/// 设置窗口 — 左右结构壳：左侧分区导航，右侧分区内容。
///
/// 「通用 / 关于」恒可交互；「视频 / 音频」在 bundle 提供对应服务后启用
/// （v0.0.6）。内容区按选中分区切换各 Content；bundle 缺成员时分区
/// 灰显占位（Avoid captive UI：无伪交互）。
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, this.services});

  final SettingsServicesBundle? services;

  /// 以默认 navigator 弹出设置窗口；全屏 route 上层同样正常浮起。
  ///
  /// Fire-and-forget 调用方可不等待返回值（返回值供需要 await 的测试使用）。
  static Future<void> show(
    BuildContext context, {
    SettingsServicesBundle? services,
  }) => showDialog(
    context: context,
    builder: (_) => SettingsDialog(services: services),
  );

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  /// 当前选中分区 —— 初始「关于」（向后兼容现状：直接打开设置看到 About）。
  _SettingsTab _selected = _SettingsTab.about;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = widget.services;
    return AppDialog(
      title: l10n.settings,
      width: 620,
      height: 440,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsNav(
            l10n: l10n,
            selected: _selected,
            onSelect: (tab) => setState(() => _selected = tab),
            // v0.0.6.1 用户裁决 (2026-09-15): 视频/音频分区暂关闭 —
            // mpv 属性链路实机验证未完成, 重新开放前维持灰显占位.
            // bundle 接线保留 (general 的断点续播开关仍消费 settings).
            videoEnabled: false,
            audioEnabled: false,
          ),
          // 左右分区的细分隔线 — 垂直渐变（上下端透明→borderHighlight），
          // 模拟毛玻璃边缘的光线收束，比通高纯色实线更轻。
          Container(
            width: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Tokens.borderHighlight,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (_selected) {
              _SettingsTab.general =>
                GeneralSettingsContent(settings: services?.settings),
              _SettingsTab.video => services?.videoProcessing == null
                  // 防御分支 —— 灰显占位项不会进入选中态；返回空视图而非伪造内容。
                  ? const SizedBox.shrink()
                  : VideoSettingsContent(
                      videoProcessing: services!.videoProcessing!,
                      settings: services.settings,
                    ),
              _SettingsTab.audio => services?.settings == null
                  ? const SizedBox.shrink()
                  : AudioSettingsContent(settings: services!.settings!),
              _SettingsTab.about => const AboutContent(),
            },
          ),
        ],
      ),
    );
  }
}

/// 左侧竖排分区导航 — 分区按服务注入情况启用/灰显。
class _SettingsNav extends StatelessWidget {
  final AppLocalizations l10n;
  final _SettingsTab selected;
  final ValueChanged<_SettingsTab> onSelect;
  final bool videoEnabled;
  final bool audioEnabled;

  const _SettingsNav({
    required this.l10n,
    required this.selected,
    required this.onSelect,
    required this.videoEnabled,
    required this.audioEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavEntry(
            tab: _SettingsTab.general,
            icon: Icons.tune,
            label: l10n.generalTab,
            enabled: true,
            selected: selected == _SettingsTab.general,
            onTap: () => onSelect(_SettingsTab.general),
          ),
          // v0.0.6: 服务注入后启用; 未注入保持灰显占位
          // （Avoid captive UI：无伪交互）。
          _NavEntry(
            tab: _SettingsTab.video,
            icon: Icons.smart_display_outlined,
            label: l10n.videoTab,
            enabled: videoEnabled,
            selected: selected == _SettingsTab.video,
            onTap: videoEnabled ? () => onSelect(_SettingsTab.video) : null,
          ),
          _NavEntry(
            tab: _SettingsTab.audio,
            icon: Icons.graphic_eq,
            label: l10n.audioTab,
            enabled: audioEnabled,
            selected: selected == _SettingsTab.audio,
            onTap: audioEnabled ? () => onSelect(_SettingsTab.audio) : null,
          ),
          _NavEntry(
            tab: _SettingsTab.about,
            icon: Icons.info_outline,
            label: l10n.aboutTab,
            enabled: true,
            selected: selected == _SettingsTab.about,
            onTap: () => onSelect(_SettingsTab.about),
          ),
        ],
      ),
    );
  }
}

/// 导航条目 — 图标 + 文字的横排行。
///
/// 灰显占位（enabled=false）：38% 不透明度 + IgnorePointer，明确传达不可点击；
/// enabled 且未选中：完整不透明 + 无底色（可点击等待选中）；
/// [selected]：bgHover 圆角底 + accent 图标/文字的持续高亮 —— 区别于 hover 的
/// 瞬态，选中态不随鼠标离开消失。
///
/// v0.0.4 交互反馈对齐控制栏按钮（custom_title_bar._TitleBarButton 同款）：
/// Material(transparent) + InkWell 水波纹禁用但保留 hover/pressed 色阶 +
/// MouseRegion click cursor —— 与纯 GestureDetector 的差异是 hover 即有
/// 底色渐现与手型光标，pressed 有按下沉降色。
class _NavEntry extends StatelessWidget {
  final _SettingsTab tab;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  const _NavEntry({
    required this.tab,
    required this.icon,
    required this.label,
    this.enabled = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !enabled,
        child: MouseRegion(
          // 可点击条目才给手型光标（与控制栏按钮同一反馈）。
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              mouseCursor: SystemMouseCursors.click,
              // 圆角裁剪 hover/pressed 色块，与行底色同轮廓。
              borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              // hover 色与选中底色同 token：未选中时 hover 渐现底色，
              // 已选中时底色本就常驻、hover 不再叠加。
              hoverColor: enabled && !selected
                  ? Tokens.bgHover
                  : Colors.transparent,
              highlightColor: enabled
                  ? Tokens.titleBarPressed
                  : Colors.transparent,
              splashColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              child: Container(
                // Key 供测试断言选中高亮（以枚举名区分条目）。
                key: ValueKey('settings-nav-${tab.name}'),
                decoration: BoxDecoration(
                  color: selected ? Tokens.bgHover : null,
                  borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spSm,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // 选中指示条 — accent 竖条从左侧点亮（对齐 AppDialog 标题
                    // 竖条/控制栏 accent 强调的同一设计语言）；未选中时保留
                    // 2px 槽位，切换不跳布局。
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: Tokens.durationFast,
                      ),
                      width: 2,
                      height: 16,
                      decoration: BoxDecoration(
                        color: selected ? Tokens.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                      ),
                    ),
                    const SizedBox(width: Tokens.spSm),
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? Tokens.accent : Tokens.textPrimary,
                    ),
                    const SizedBox(width: Tokens.spSm),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Tokens.accent : Tokens.textPrimary,
                          fontSize: Tokens.fontCaption,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
