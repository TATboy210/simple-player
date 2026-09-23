import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
// services: LogicalKeyboardKey / KeyEventResult (material.dart 不完整导出).
import 'package:flutter/services.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../kernel/services/video_processing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/control_bar_decoration.dart';
import '../../shared/glass_blur_layer.dart';
import '../../shared/glass_container.dart' show GlassButton;
import '../../shared/loop_marquee_text.dart';
import '../../theme/tokens.dart';
import 'about_content.dart';
import 'audio_settings_content.dart';
import 'general_settings_content.dart';
import 'video_settings_content.dart';

/// 设置分区 —— 左侧导航的四个条目。
enum _SettingsTab { general, video, audio, about }

/// 面板层级 —— 两级覆盖导航（XMB 交叉模型，通用模式实现）：
/// L0 tag 层（竖排分区入口）→ L1 内容层（从右滑入覆盖，tag 层虚化后退）。
enum _PanelLevel { tags, content }

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

/// 设置面板 — 停靠于控制层 Stack 中列的两级玻璃面板。
///
/// 控制栏/播放列表同款壳（ControlBarDecoration playing + GlassTier.normal
/// 缓存模糊 + controlBarRadius 圆角）；渐进渐退为纯 opacity FadeTransition
/// （渲染层驱动，动画期间 widget 树零重建），IgnorePointer 锚定 [visible]
/// 杜绝渐退中"虚空点击"。
///
/// 交互（v0.0.9 键盘重定义）：
/// - L0 tag 层：竖排分区入口撑满内容区（居中对称，宽度随面板响应，
///   摘要跑马灯随宽度联动），↑↓ 切换、→ 或 Enter 进入；tag 反馈沿用
///   hover/pressed 色阶语言，无选中竖条
/// - L1 内容层：从右滑入覆盖标题行以下区域，
///   L0 后退（左移+微缩）淡出至完全消失（纯渲染层动画，零新增 GPU）
/// - 键盘：→ 进入 L1 / 切下一分区；L1 ← 返回 L0；↑↓ 选条目（General
///   分区经 [GeneralSettingsContent.rowsFocusNode] 下沉消费）、Enter/Space
///   激活；Esc 任何层级冒泡宿主关整个面板；面板聚焦期间 Space 不再
///   透传播放/暂停
/// - 灰显分区（视频/音频）键盘不可达：←→/↑↓ 只在 enabled 集合内移动
///   （键盘绕过 IgnorePointer，必须显式过滤）
///
/// 焦点纪律：面板从不调用 unfocus——隐藏时由宿主
/// （PlayerVideoControls 监听 settingsVisible）显式 requestFocus 归还，
/// 避免 `unfocus()` 落到路由 scope 造成全屏按键死区。
class SettingsPanel extends StatefulWidget {
  /// 面板是否可见 — 驱动渐入渐出动画 (宿主共享 notifier, 全屏同源).
  final bool visible;

  /// 关闭回调 — 标题行关闭按钮触发, 宿主翻转 settingsVisible notifier.
  final VoidCallback onClose;

  final SettingsServicesBundle? services;

  /// seek 拖动挂起信号 (v0.0.8.2, 可选) — true 时玻璃模糊短暂停用,
  /// 松手恢复. null = 无挂起源 (恒不挂起).
  final ValueListenable<bool>? scrubbing;

  const SettingsPanel({
    super.key,
    required this.visible,
    required this.onClose,
    this.services,
    this.scrubbing,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with TickerProviderStateMixin {
  /// 键盘可达分区 — audio 已解灰（v0.0.8.1：audio delay 实现完整，仅 UI
  /// 被灰显），video 仍灰显（视频处理走控制层，无面板内容需求）.
  static const List<_SettingsTab> _enabledTabs = [
    _SettingsTab.general,
    _SettingsTab.audio,
    _SettingsTab.about,
  ];

  /// 当前分区 — 跨显隐持久（State 常驻 = "记忆上次 L1" 免费实现）.
  _SettingsTab _selected = _SettingsTab.about;

  /// 当前层级 — 首次打开 L0；进入内容层后保持（同上）.
  _PanelLevel _level = _PanelLevel.tags;

  /// 渐入渐出动画 — 与控制栏/播放列表同款（FadeTransition + easeInOut +
  /// durationControlsFade）.
  late final AnimationController _controller;

  late final Animation<double> _fade;

  /// 层级切换动画 — L0 虚化 + L1 滑入共用（150ms easeInOut，与家族同节奏）.
  late final AnimationController _layerController;

  late final CurvedAnimation _layerEase;

  /// 面板级焦点 — ←→ 切分区 / Enter 进出层级 / Esc 逐层.
  late final FocusNode _focusNode;

  /// General 分区行导航焦点 — ↑↓ 选条目 / Enter 激活（注入 content）.
  late final FocusNode _rowsFocusNode;

  /// 面板装饰 — 控制栏同款 playing 装饰, 静态缓存 (同 PlaylistPanel).
  static final _panelDecoration = ControlBarDecoration.playing(
    borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
  );

  /// L0 tag 层子树缓存 (v0.0.8.2 渲染优化) — 面板开关/层级翻转的 setState
  /// 不再全量重跑 tag 层 build（与 _controlBarCache 同款 identity 复用：
  /// identical widget 短路 element diff，chips×4 + 跑马灯 LayoutBuilder×4
  /// 的 build 方法整树跳过）。失效点：_selected 变化 / locale 变化。
  Widget? _tagLayerCache;

  /// L1 内容层子树缓存 — 同上；AnimatedSwitcher + 当前分区内容子树。
  Widget? _contentLayerCache;

  /// 缓存构建时的 locale — 语言切换（App 级重建）经 build 时的 locale
  /// 比对失效缓存，防止缓存的 l10n 字符串陈旧。
  Locale? _layerCacheLocale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
    )..value = widget.visible ? 1.0 : 0.0;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _layerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationNormal),
    );
    _layerEase = CurvedAnimation(
      parent: _layerController,
      curve: Curves.easeInOut,
    );
    _focusNode = FocusNode(debugLabel: 'SettingsPanel');
    _rowsFocusNode = FocusNode(debugLabel: 'SettingsPanelRows');
    if (widget.visible) {
      // post-frame：等面板挂上树再取焦点（initState 内不能同步请求）.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.visible) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
      // 重开面板：焦点回面板级（宿主在关闭时已归还外层；此处为打开侧接力）.
      if (widget.visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.visible) _focusNode.requestFocus();
        });
      }
    }
    // services 替换 → 内容层缓存失效（分区内容依赖 services 注入）。
    // 注意：visible 翻转/宿主重建**不**失效——这正是打开帧零重建的关键。
    if (oldWidget.services != widget.services) _contentLayerCache = null;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _rowsFocusNode.dispose();
    _layerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── 层级流转 ──────────────────────────────────────────────────

  /// _selected 变更统一入口 — setState 同时失效两层子树缓存（tag 层的
  /// 选中高亮与内容层的 KeyedSubtree key 都依赖 _selected，漏失效会
  /// 高亮/内容陈旧）。
  void _changeSelected(_SettingsTab tab) {
    setState(() {
      _selected = tab;
      _tagLayerCache = null;
      _contentLayerCache = null;
    });
  }

  /// L0 → L1（点 tag / Enter）— 进入即聚焦 General 首行（键盘 ↑↓ 立即可用）.
  void _enterContent() {
    setState(() => _level = _PanelLevel.content);
    _layerController.forward();
    if (_selected == _SettingsTab.general) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _level == _PanelLevel.content) {
          _rowsFocusNode.requestFocus();
        }
      });
    }
  }

  /// L1 → L0（← / Esc）— 焦点回面板级（tag 层 ↑↓ 恢复可用）.
  void _backToTags() {
    setState(() => _level = _PanelLevel.tags);
    _layerController.reverse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// L1 内 → 切分区 — 离开/进入 general 时 post-frame 归还/接力焦点
  /// （rows 节点随分区 unmount，同步 requestFocus 会被 dispose 覆盖 —
  /// 实测坑）.
  void _switchTo(_SettingsTab tab) {
    if (tab == _selected) return;
    final wasGeneral = _selected == _SettingsTab.general;
    _changeSelected(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _level != _PanelLevel.content) return;
      if (wasGeneral) {
        _focusNode.requestFocus();
      } else if (_selected == _SettingsTab.general) {
        _rowsFocusNode.requestFocus();
      }
    });
  }

  // ── 键盘（XMB 交叉模型）──────────────────────────────────────

  /// 面板级按键 — 返回 handled 阻断冒泡（防外层 seek/音量/暂停泄漏），
  /// Esc 在 L0 时刻意 ignored（冒泡 → 宿主 onEscapePressed 关面板）.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 防线：焦点滞留隐藏面板时绝不吞键（宿主负责归还焦点，此处兜底）.
    if (!widget.visible) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_level == _PanelLevel.tags) {
      return _handleTagsLevelKey(key);
    }
    return _handleContentLevelKey(key);
  }

  /// L0 — ↑↓ 在 tag 列间移动（enabled 集合内到头即停），→ 或 Enter/Space
  /// 进入内容层；← handled 空操作（ignored 会冒泡成 seek）；Esc 冒泡关面板.
  KeyEventResult _handleTagsLevelKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final dir = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final index = _enabledTabs.indexOf(_selected);
      final next = (index + dir).clamp(0, _enabledTabs.length - 1);
      if (next != index) {
        _changeSelected(_enabledTabs[next]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _enterContent();
      return KeyEventResult.handled;
    }
    // ← handled 空操作（挡 seek 泄漏）；Esc/其余 — 冒泡（Esc 关面板）.
    if (key == LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// L1 — → 切下一分区；← 返回 tag 层；↑↓/Enter/Space 交给 rows 节点
  /// （General 后代先消费，未聚焦则聚焦）；非 General 分区同键 handled
  /// 空操作（防泄漏）；Esc 冒泡宿主关整个面板（返回专属 ← 键）.
  KeyEventResult _handleContentLevelKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight) {
      final index = _enabledTabs.indexOf(_selected);
      final next = (index + 1).clamp(0, _enabledTabs.length - 1);
      if (next != index) {
        _switchTo(_enabledTabs[next]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _backToTags();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (_selected == _SettingsTab.general && !_rowsFocusNode.hasFocus) {
        _rowsFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    // Esc/其余 — 冒泡（Esc 经宿主 onEscapePressed 关整个面板）.
    return KeyEventResult.ignored;
  }

  // ── 构建 ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 纯渲染层驱动; IgnorePointer
    // 锚定 widget.visible: 关闭瞬间立即让出命中.
    return IgnorePointer(
      ignoring: !widget.visible,
      child: RepaintBoundary(
        child: FadeTransition(opacity: _fade, child: _buildShell(context)),
      ),
    );
  }

  /// 控制栏同款玻璃壳 — 对照 PlaylistPanel._buildShell (无 EdgeGlow,
  /// 同层两面板视觉一致优先).
  ///
  /// v0.0.8.2 收敛到 [GlassBlurLayer] — 门控语义不变（淡出 <1% 停用
  /// GPU 背景采样），内容子树仍走常量 child，动画帧只换 enabled 布尔
  /// （零重建契约保持）。
  Widget _buildShell(BuildContext context) {
    return Container(
      decoration: _panelDecoration,
      child: GlassBlurLayer(
        borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
        opacity: _fade,
        suspend: widget.scrubbing,
        child: Material(
          // 透明 Material 祖先 — InkWell hover 色阶与 About 链接依赖它.
          color: Colors.transparent,
          child: Focus(
            focusNode: _focusNode,
            // Tab 遍历不进面板（requestFocus 不受影响）.
            skipTraversal: true,
            onKeyEvent: _handleKeyEvent,
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  /// L0 tag 层缓存取用 — 缓存内含 RepaintBoundary（退入场动画的重绘
  /// 隔离到 L0 子层）。命中时 identical widget 短路 element diff，
  /// chips×4 + 跑马灯 LayoutBuilder×4 的 build 方法整树跳过。
  /// Key 供测试断言缓存命中（实例 identity）。
  Widget _cachedTagLayer(BuildContext context) =>
      _tagLayerCache ??= RepaintBoundary(
        key: ValueKey('settings-l0-boundary-${_selected.name}'),
        child: _buildTagLayer(context),
      );

  /// L1 内容层缓存取用 — 同上；AnimatedSwitcher + 当前分区内容子树。
  Widget _cachedContentLayer(BuildContext context) =>
      _contentLayerCache ??= RepaintBoundary(
        key: ValueKey('settings-l1-boundary-${_selected.name}'),
        child: _buildContentLayer(context),
      );

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // locale 门 — Localizations.localeOf 注册依赖，语言切换（App 级重建）
    // 触发本 build 后此处失缓存，防缓存内 l10n 字符串陈旧。
    final locale = Localizations.localeOf(context);
    if (_layerCacheLocale != locale) {
      _layerCacheLocale = locale;
      _tagLayerCache = null;
      _contentLayerCache = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header 重绘隔离 — backOpacity FadeTransition 与层动画并行期间
        // 只重录 header 子层, 不连带 tag/内容层 (v0.0.8.2 渲染优化).
        RepaintBoundary(
          child: _PanelHeader(
            l10n: l10n,
            onBack: _backToTags,
            onClose: widget.onClose,
            showBack: _level == _PanelLevel.content,
            backOpacity: _layerEase,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              // L0 tag 层 — 进入 L1 后退（左移+微缩）淡出至完全消失并
              // 让出命中（D3）; 退出 L1 反向回来. TickerMode 在隐藏/L1 时
              // 静音跑马灯与 chip 隐式动画（零白耗 ticker）.
              TickerMode(
                enabled: widget.visible && _level == _PanelLevel.tags,
                child: IgnorePointer(
                  ignoring: _level == _PanelLevel.content,
                  child: AnimatedBuilder(
                    animation: _layerEase,
                    // child 走缓存 (v0.0.8.2) — 动画帧只换 Opacity/Transform
                    // 矩阵；level 翻转/面板开关的 setState 帧也 identity 复用
                    // (identical widget 短路 diff), chips+跑马灯 build 跳过.
                    child: _cachedTagLayer(context),
                    builder: (context, child) {
                      final t = _layerEase.value;
                      return Opacity(
                        opacity: 1.0 - t,
                        child: Transform.translate(
                          offset: Offset(-16 * t, 0),
                          child: Transform.scale(
                            scale: 1.0 - 0.04 * t,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // L1 内容层 — 从右滑入覆盖标题行以下区域;
              // L0 静止期 Offstage（不 paint/不命中/语义不可见），滑出
              // 动画期间保持挂载以呈现退出动效.
              // 内容层走 child: 参数 — 动画帧只换 Offstage 开关，
              // Row/分区内容子树零重建（修复每帧全量重建卡顿）.
              AnimatedBuilder(
                animation: _layerController,
                child: IgnorePointer(
                  ignoring: _level == _PanelLevel.tags,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(_layerEase),
                    // 缓存同 L0 — level 翻转不重建内容子树, 只有 _selected
                    // 变化 (分区切换) 才失效重建.
                    child: _cachedContentLayer(context),
                  ),
                ),
                builder: (_, child) {
                  final offstage =
                      _level == _PanelLevel.tags &&
                      !_layerController.isAnimating;
                  return Offstage(offstage: offstage, child: child);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// L0 tag 层 — 竖排分区入口，撑满内容区（水平对称居中），
  /// 宽度随面板/窗口响应；摘要跑马灯的滚动空间随之联动.
  Widget _buildTagLayer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tab in _SettingsTab.values)
            _SettingsTabChip(
              tab: tab,
              selected: _selected == tab,
              enabled: _enabledTabs.contains(tab),
              // 一步直达 — 点击任意 enabled tag 选中并进入其内容层.
              onTap: () {
                if (_level != _PanelLevel.tags) return;
                _changeSelected(tab);
                _enterContent();
              },
            ),
        ],
      ),
    );
  }

  /// L1 内容层 — 分区内容（方向性滑动切换）.
  Widget _buildContentLayer(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: Tokens.durationNormal),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            // 顶部对齐 — 分区内容高度不同时切换不跳中.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) {
              // 方向性滑动 — 进入者从右侧滑入, 退出者向左滑出（恒正向:
              // L1 内只剩 → 切下一分区, ← 已改为返回 tag 层）.
              final isIncoming = child.key == ValueKey(_selected);
              final offset = isIncoming
                  ? const Offset(1, 0)
                  : const Offset(-1, 0);
              // RepaintBoundary — 分区切换 150ms 内出入双子树并存, 各自
              // 隔离重绘区域 (layout 双算不可避免, paint 减半).
              return RepaintBoundary(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: offset,
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: _buildTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  /// 分区内容 switch — 内容组件零改动复用（拓展点：服务启用后自动获得
  /// L1 通道）; 灰显防御分支返回空视图而非伪造内容.
  Widget _buildTabContent() {
    final services = widget.services;
    return switch (_selected) {
      _SettingsTab.general => GeneralSettingsContent(
        settings: services?.settings,
        rowsFocusNode: _rowsFocusNode,
      ),
      _SettingsTab.video =>
        services?.videoProcessing == null
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
    };
  }
}

/// 面板标题行 — "设置" + 返回按钮（仅 L1 出现） + 关闭按钮。
///
/// 无 accent 竖条（v0.0.8 用户裁决）；返回按钮出现在"设置"右侧，
/// 淡入淡出 + 恒定占位防标题跳动；字号/按钮与播放列表标题行同规格。
class _PanelHeader extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final bool showBack;
  final Animation<double> backOpacity;

  const _PanelHeader({
    required this.l10n,
    required this.onBack,
    required this.onClose,
    required this.showBack,
    required this.backOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.spMd,
        Tokens.spMd,
        Tokens.spSm,
        Tokens.spSm,
      ),
      child: Row(
        children: [
          Text(
            l10n.settings,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Tokens.spSm),
          // 返回按钮 — 仅 L1 出现（层级动画驱动淡入淡出，恒占位防跳）.
          FadeTransition(
            opacity: backOpacity,
            child: IgnorePointer(
              ignoring: !showBack,
              child: Opacity(
                opacity: showBack ? 1.0 : 0.0,
                child: GlassButton.iconOnly(
                  icon: Icons.arrow_back,
                  tooltip: l10n.back,
                  onPressed: onBack,
                ),
              ),
            ),
          ),
          const Spacer(),
          GlassButton.iconOnly(
            icon: Icons.close,
            tooltip: l10n.close,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// 竖排分区 tag — 图标 + 类别名 + 条目枚举摘要小字（三行，左对齐）。
///
/// hover/pressed 色阶沿用旧 _NavEntry 语言（hover 渐现 bgHover、pressed
/// 按下沉降色）；选中态 = bgHover 常驻底 + accent 图标/文字，**无竖条
/// 指示**（v0.0.8 裁决）。灰显分区 38% 不透明 + IgnorePointer。
class _SettingsTabChip extends StatefulWidget {
  final _SettingsTab tab;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SettingsTabChip({
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_SettingsTabChip> createState() => _SettingsTabChipState();
}

class _SettingsTabChipState extends State<_SettingsTabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = widget.selected;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.enabled ? widget.onTap : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              // Key 供测试断言选中底色（以枚举名区分分区）.
              key: ValueKey('settings-tab-${widget.tab.name}'),
              duration: const Duration(milliseconds: Tokens.durationFast),
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spSm,
                vertical: Tokens.spSm,
              ),
              decoration: BoxDecoration(
                // 选中恒亮 / 悬停瞬态同底色（_NavEntry 同款语义）。
                color: (selected || _hovered) && widget.enabled
                    ? Tokens.bgHover
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _tabIcon(widget.tab),
                        size: 18,
                        color: selected && widget.enabled
                            ? Tokens.accent
                            : Tokens.textPrimary,
                      ),
                      const SizedBox(width: Tokens.spSm),
                      Text(
                        _tabLabel(l10n),
                        style: TextStyle(
                          color: selected && widget.enabled
                              ? Tokens.accent
                              : Tokens.textPrimary,
                          fontSize: Tokens.fontBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.spXs),
                  // 摘要跑马灯 — 空间足够静止全显, 不足从右向左循环滚动;
                  // 滚动空间随 chip 宽（面板宽）响应联动.
                  LoopMarqueeText(
                    text: _tabSummary(l10n),
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _tabIcon(_SettingsTab tab) => switch (tab) {
    _SettingsTab.general => Icons.tune,
    _SettingsTab.video => Icons.smart_display_outlined,
    _SettingsTab.audio => Icons.graphic_eq,
    _SettingsTab.about => Icons.info_outline,
  };

  String _tabLabel(AppLocalizations l10n) => switch (widget.tab) {
    _SettingsTab.general => l10n.generalTab,
    _SettingsTab.video => l10n.videoTab,
    _SettingsTab.audio => l10n.audioTab,
    _SettingsTab.about => l10n.aboutTab,
  };

  String _tabSummary(AppLocalizations l10n) => switch (widget.tab) {
    _SettingsTab.general => l10n.settingsSummaryGeneral,
    _SettingsTab.video => l10n.settingsSummaryVideo,
    _SettingsTab.audio => l10n.settingsSummaryAudio,
    _SettingsTab.about => l10n.settingsSummaryAbout,
  };
}
