import 'package:flutter/material.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/control_bar_decoration.dart';
import '../../shared/glass_container.dart' show GlassButton, GlassTier;
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

/// 设置面板 — 左右结构壳：左侧分区导航，右侧分区内容。
///
/// 控制栏/播放列表同款停靠玻璃面板 (v0.0.7.2 面板化重构)：脱离 AppDialog
/// 的 Dialog 包装，壳与动画逐字对齐 [PlaylistPanel] —— ControlBarDecoration
/// playing 装饰 + GlassTier.normal 缓存模糊 + controlBarRadius 圆角；
/// 渐进渐退为纯 opacity FadeTransition (渲染层驱动，动画期间 widget 树
/// 零重建)，IgnorePointer 锚定 [visible] 杜绝渐退中"虚空点击"。
///
/// 挂载于 PlayerVideoControls 控制层 Stack 中列（与播放列表同层，右列
/// 避让见挂载点）：无 route barrier，打开时标题栏拖动不受阻；错误卡片
/// 挂于 root Stack Navigator 之上，面板重排不影响报错功能。
///
/// 「通用 / 关于」恒可交互；「视频 / 音频」在 bundle 提供对应服务后启用
/// （v0.0.6）。内容区按选中分区切换各 Content；bundle 缺成员时分区
/// 灰显占位（Avoid captive UI：无伪交互）。
class SettingsPanel extends StatefulWidget {
  /// 面板目标内容尺寸 — 经 max 约束生效：槽位充足时恒为此尺寸，
  /// 不足时精确收缩（固定 SizedBox 在 854×480 + 播放列表同开、槽宽
  /// 仅 526 时会溢出，故用 ConstrainedBox(max) + SizedBox.expand）。
  static const double panelMaxWidth = 620.0;
  static const double panelMaxHeight = 440.0;

  /// 面板是否可见 — 驱动渐入渐出动画 (宿主共享 notifier, 全屏同源).
  final bool visible;

  /// 关闭回调 — 标题行关闭按钮触发, 宿主翻转 settingsVisible notifier.
  final VoidCallback onClose;

  final SettingsServicesBundle? services;

  const SettingsPanel({
    super.key,
    required this.visible,
    required this.onClose,
    this.services,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with SingleTickerProviderStateMixin {
  /// 当前选中分区 —— 初始「关于」（向后兼容现状：直接打开设置看到 About）。
  _SettingsTab _selected = _SettingsTab.about;

  /// 渐进渐退动画 — 与控制栏/播放列表同款 (FadeTransition + easeInOut +
  /// durationControlsFade)，照抄 PlaylistPanel 实现保持三面板一致.
  late final AnimationController _controller;

  late final Animation<double> _fade;

  /// 面板装饰 — 控制栏同款 playing 装饰, 静态缓存 (同 PlaylistPanel).
  static final _panelDecoration = ControlBarDecoration.playing(
    borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = widget.visible ? 1.0 : 0.0;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 纯渲染层驱动, 动画全程
    // widget 树零重建; IgnorePointer 锚定 widget.visible: 关闭瞬间立即
    // 让出命中 (与播放列表同一竞态防治).
    return IgnorePointer(
      ignoring: !widget.visible,
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _fade,
          // max 约束 + expand: 槽位充足时恒 620×440, 不足时收缩填满槽位
          // (Center 负责槽内居中).
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: SettingsPanel.panelMaxWidth,
              maxHeight: SettingsPanel.panelMaxHeight,
            ),
            child: SizedBox.expand(child: _buildShell(context)),
          ),
        ),
      ),
    );
  }

  /// 控制栏同款玻璃壳 — 对照 PlaylistPanel._buildShell (无 EdgeGlow,
  /// 同层两面板视觉一致优先).
  Widget _buildShell(BuildContext context) {
    return Container(
      decoration: _panelDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
        child: BackdropFilter(
          filter: GlassTier.normal.blurFilter,
          child: Material(
            // 透明 Material 祖先 — nav 条目的 InkWell hover 色阶与
            // About 链接按钮的水波纹/命中依赖它 (原 AppDialog 亦有此层).
            color: Colors.transparent,
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = widget.services;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题行 — 与播放列表同款呼吸过渡 (无分割线), 关闭按钮 GlassButton 收口.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spMd,
            Tokens.spMd,
            Tokens.spSm,
            Tokens.spSm,
          ),
          child: _PanelHeader(l10n: l10n, onClose: widget.onClose),
        ),
        Expanded(
          child: Row(
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
                  _SettingsTab.general => GeneralSettingsContent(
                    settings: services?.settings,
                  ),
                  _SettingsTab.video =>
                    services?.videoProcessing == null
                        // 防御分支 —— 灰显占位项不会进入选中态；返回空视图而非伪造内容。
                        ? const SizedBox.shrink()
                        : VideoSettingsContent(
                            videoProcessing: services!.videoProcessing!,
                            settings: services.settings,
                          ),
                  _SettingsTab.audio =>
                    services?.settings == null
                        ? const SizedBox.shrink()
                        : AudioSettingsContent(settings: services!.settings!),
                  _SettingsTab.about => const AboutContent(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 面板标题行 — accent 竖条 + 标题 + 关闭按钮。
///
/// 关闭按钮用 GlassButton.iconOnly（播放列表 _buildNormalHeader 同款
/// 方块风格）；accent 竖条规格取自原 AppDialog._DialogTitle（3×16,
/// radiusBtn 圆角），保留设置面板原有的选中强调语言。
class _PanelHeader extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onClose;

  const _PanelHeader({required this.l10n, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // accent 竖条 — 与标题字号对齐的强调标识 (继承自 AppDialog 标题行).
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: Tokens.accent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          ),
        ),
        const SizedBox(width: Tokens.spSm),
        Expanded(
          child: Text(
            l10n.settings,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GlassButton.iconOnly(
          icon: Icons.close,
          tooltip: l10n.close,
          onPressed: onClose,
        ),
      ],
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
                    // 选中指示条 — accent 竖条从左侧点亮（对齐控制栏 accent
                    // 强调的同一设计语言）；未选中时保留 2px 槽位，切换不跳布局。
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
