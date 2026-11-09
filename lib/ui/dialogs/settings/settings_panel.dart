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
import '../../shared/secondary_surface_visibility.dart';
import '../../theme/tokens.dart';
import 'about_content.dart';
import 'settings_panel_session.dart';
import '../../player/workspace_focus_scope.dart';
import 'audio_settings_content.dart';
import 'general_settings_content.dart';
import 'video_settings_content.dart';

part 'settings_panel_chrome.dart';
part 'settings_panel_keys.dart';
part 'settings_panel_layers.dart';
part 'settings_panel_motion.dart';
part 'settings_panel_tabs.dart';

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
///   激活；Esc 任何层级冒泡宿主，仅退出全屏；面板聚焦期间 Space 不再
///   透传播放/暂停
/// - 灰显分区（video）键盘不可达：←→/↑↓ 只在 enabled 集合内移动
///   （键盘绕过 IgnorePointer，必须显式过滤）；audio 行级键盘可达
///   （261009-upn：rowsFocusNode 注入，General 同模式）
///
/// 焦点纪律：面板从不调用 unfocus——隐藏时由宿主
/// （PlayerVideoControls 监听 settingsVisible）显式 requestFocus 归还，
/// 避免 `unfocus()` 落到路由 scope 造成全屏按键死区。
///
/// 性能契约：L0/L1 两层子树以 widget identity 缓存（见 State），因此宿主
/// 必须复用同一个 [services] 数据包实例——每次 build 新建会穿透缓存。
class SettingsPanel extends StatefulWidget {
  /// 面板是否可见 — 驱动渐入渐出动画 (宿主共享 notifier, 全屏同源).
  final bool visible;

  /// 关闭回调 — 标题行关闭按钮触发, 宿主翻转 settingsVisible notifier.
  final VoidCallback onClose;

  final SettingsServicesBundle? services;

  /// 共享展示数据；不共享各 route 的 FocusNode 或 ScrollController。
  final SettingsPanelSession? session;

  /// 左任务标题显式提升动作；中任务不显示提升入口。
  final VoidCallback? onPromote;

  /// seek 拖动挂起信号 (v0.0.8.2, 可选) — true 时玻璃模糊短暂停用,
  /// 松手恢复. null = 无挂起源 (恒不挂起).
  final ValueListenable<bool>? scrubbing;

  /// 窗口 resize 信号 (可选) — true 时玻璃模糊挂起, 结束恢复. null = 不挂起.
  final ValueListenable<bool>? resizing;

  const SettingsPanel({
    super.key,
    required this.visible,
    required this.onClose,
    this.services,
    this.session,
    this.onPromote,
    this.scrubbing,
    this.resizing,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with TickerProviderStateMixin, _PanelKeyHandling {
  /// 当前分区 — 跨显隐持久（State 常驻 = "记忆上次 L1" 免费实现）.
  @override
  _SettingsTab _selected = _SettingsTab.about;

  /// 当前层级 — 首次打开 L0；进入内容层后保持（同上）.
  @override
  _PanelLevel _level = _PanelLevel.tags;

  /// 渐入渐出 + 层级切换两组动画 — 需要 `this` 作 vsync，故 initState 内
  /// 构造（唯一保留的 late final，生命周期与 State 严格一致）.
  late final _PanelMotion _motion;

  /// 面板级焦点 — ←→ 切分区 / Enter 进出层级 / Esc 退出全屏.
  final FocusNode _focusNode = FocusNode(debugLabel: 'SettingsPanel');

  /// General 分区行导航焦点 — ↑↓ 选条目 / Enter 激活（注入 content）.
  @override
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'SettingsPanelRows');

  /// Audio 分区行导航焦点 — 与 General 同模式（261009-upn 补齐键盘行
  /// 导航；独立节点：AnimatedSwitcher 过渡期两分区内容短暂并存，共用
  /// 单节点会触发重复附着断言）.
  @override
  final FocusNode _audioRowsFocusNode = FocusNode(
    debugLabel: 'SettingsPanelAudioRows',
  );

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

  // General may survive as AnimatedSwitcher's outgoing child; cancel immediately.
  final ValueNotifier<bool> _generalEligible = ValueNotifier(false);

  /// 缓存构建时的 locale — 语言切换（App 级重建）经 build 时的 locale
  /// 比对失效缓存，防止缓存的 l10n 字符串陈旧。
  Locale? _layerCacheLocale;

  /// 控制器只在本 route 附着；会话中仅存数值。
  final Map<String, ScrollController> _scrollControllers = {};
  final FocusScopeNode _taskScope = FocusScopeNode(debugLabel: 'settings-task');
  WorkspaceFocusRegistry? _focusRegistry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 换注册表：旧 registry 注销（identical 守卫防误删）→ 重读 → 新 registry
    // 注册（identical 重绑为幂等 no-op）。
    _focusRegistry?.unregisterTask(WorkspaceTaskIds.settings, _taskScope);
    _focusRegistry = WorkspaceFocusScope.maybeOf(context);
    _focusRegistry?.registerTask(WorkspaceTaskIds.settings, _taskScope);
  }

  /// 从共享数据同步导航；滚动通知不触发整层重建。
  void _syncSession() {
    final state = widget.session?.value;
    if (state == null) return;
    final selected = _tabByName(state.section);
    final level = state.isContent ? _PanelLevel.content : _PanelLevel.tags;
    _followSharedScroll(state.scrollOffsets);
    if (_selected == selected && _level == level) return;
    setState(() {
      if (_selected != selected) _invalidateLayerCaches();
      _selected = selected;
      _level = level;
    });
    _motion.layerController.value = state.isContent ? 1 : 0;
  }

  /// 分区名 → 枚举；未知名回落 about（与旧会话数据兼容）.
  static _SettingsTab _tabByName(String name) => _SettingsTab.values.firstWhere(
    (tab) => tab.name == name,
    orElse: () => _SettingsTab.about,
  );

  /// An already mounted window route also follows fullscreen scroll changes.
  void _followSharedScroll(Map<String, double> offsets) {
    for (final entry in _scrollControllers.entries) {
      final offset = offsets[entry.key];
      final controller = entry.value;
      if (offset == null ||
          !controller.hasClients ||
          (controller.offset - offset).abs() < 0.1) {
        continue;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.hasClients) return;
        controller.jumpTo(
          offset.clamp(0.0, controller.position.maxScrollExtent),
        );
      });
    }
  }

  /// 两层子树缓存同时失效 — 选中高亮/内容 key/locale/services 变化共用.
  void _invalidateLayerCaches() {
    _tagLayerCache = null;
    _contentLayerCache = null;
  }

  /// 发布展示数据，不把角色变动混入设置业务状态。
  void _recordNavigation() =>
      widget.session?.navigate(_selected.name, _level == _PanelLevel.content);

  /// 获取独立分区控制器，首次按共享 offset 恢复。
  ScrollController _scrollFor(String section) => _scrollControllers.putIfAbsent(
    section,
    () => ScrollController(
      initialScrollOffset: widget.session?.value.scrollOffsets[section] ?? 0,
    ),
  );

  @override
  void initState() {
    super.initState();
    _motion = _PanelMotion(vsync: this, visible: widget.visible);
    final presentation = widget.session?.value;
    if (presentation != null) {
      _selected = _tabByName(presentation.section);
      _level = presentation.isContent ? _PanelLevel.content : _PanelLevel.tags;
      _motion.layerController.value = presentation.isContent ? 1 : 0;
    }
    widget.session?.addListener(_syncSession);
    if (widget.visible) _requestPanelFocusWhenReady();
  }

  /// post-frame：等面板挂上树再取焦点（initState 内不能同步请求），
  /// 且仅当本 route 仍为当前 route.
  void _requestPanelFocusWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.visible &&
          ModalRoute.of(context)?.isCurrent != false) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      // A replacement task source is a new owner, even with identical navigation.
      _generalEligible.value = false;
      oldWidget.session?.removeListener(_syncSession);
      widget.session?.addListener(_syncSession);
      _syncSession();
    }
    if (oldWidget.visible != widget.visible) {
      widget.visible
          ? _motion.fadeController.forward()
          : _motion.fadeController.reverse();
      // 重开面板：焦点回面板级（宿主在关闭时已归还外层；此处为打开侧接力）.
      if (widget.visible) _requestPanelFocusWhenReady();
    }
    // services 替换 → 内容层缓存失效（分区内容依赖 services 注入）。
    // 注意：visible 翻转/宿主重建**不**失效——这正是打开帧零重建的关键。
    if (oldWidget.services != widget.services) _contentLayerCache = null;
  }

  @override
  void dispose() {
    widget.session?.removeListener(_syncSession);
    _generalEligible.value = false;
    _generalEligible.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    // identical 守卫已内置契约方法 — 只清自己的注册，不动后来者。
    _focusRegistry?.unregisterTask(WorkspaceTaskIds.settings, _taskScope);
    _taskScope.dispose();
    _focusNode.dispose();
    _rowsFocusNode.dispose();
    _audioRowsFocusNode.dispose();
    _motion.dispose();
    super.dispose();
  }

  // ── 层级流转 ──────────────────────────────────────────────────

  /// _selected 变更统一入口 — setState 同时失效两层子树缓存（tag 层的
  /// 选中高亮与内容层的 KeyedSubtree key 都依赖 _selected，漏失效会
  /// 高亮/内容陈旧）。
  @override
  void _changeSelected(_SettingsTab tab) {
    setState(() {
      _selected = tab;
      _invalidateLayerCaches();
    });
    _recordNavigation();
  }

  /// L0 → L1（点 tag / Enter）— 进入即聚焦 General/audio 首行
  /// （键盘 ↑↓ 立即可用；video/about 无行导航不聚焦）.
  @override
  void _enterContent() {
    setState(() => _level = _PanelLevel.content);
    _motion.layerController.forward();
    _recordNavigation();
    // 行导航分区 → 行焦点节点（注入 content 消费 ↑↓/Enter；其余 null）.
    final rowsNode = _rowsNodeFor(_selected);
    if (rowsNode == null) return;
    // post-frame：等分区内容挂上树再聚焦（节点随 content 附着）.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _level == _PanelLevel.content) rowsNode.requestFocus();
    });
  }

  /// L1 → L0（← / Esc）— 焦点回面板级（tag 层 ↑↓ 恢复可用）.
  @override
  void _backToTags() {
    setState(() => _level = _PanelLevel.tags);
    _motion.layerController.reverse();
    _recordNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// 点击 tag — 一步直达：选中并进入其内容层（仅 L0 响应）.
  void _onTagTapped(_SettingsTab tab) {
    if (_level != _PanelLevel.tags) return;
    _changeSelected(tab);
    _enterContent();
  }

  /// 内容层滚动 → 共享展示数据. Only the active route writes; a hidden
  /// window route may clamp its shorter viewport while following fullscreen.
  void _onContentScrolled(double pixels) =>
      widget.session?.recordScroll(_selected.name, pixels);

  // ── 构建 ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 控制栏同款渐进渐退 — FadeTransition 纯渲染层驱动; IgnorePointer
    // 锚定 widget.visible: 关闭瞬间立即让出命中.
    return SecondarySurfaceOwner(
      visible: widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: TickerMode(
          enabled: widget.visible,
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _motion.fade,
                child: _buildShell(context),
              ),
            ),
          ),
        ),
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
        opacity: _motion.fade,
        suspend: widget.scrubbing,
        resizing: widget.resizing,
        child: Material(
          // 透明 Material 祖先 — InkWell hover 色阶与 About 链接依赖它.
          color: Colors.transparent,
          child: FocusScope(
            node: _taskScope,
            child: Focus(
              focusNode: _focusNode,
              // Tab 遍历不进面板（requestFocus 不受影响）.
              skipTraversal: true,
              onKeyEvent: _handleKeyEvent,
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  /// L0 tag 层缓存取用 — 缓存内含 RepaintBoundary（退入场动画的重绘
  /// 隔离到 L0 子层）。命中时 identical widget 短路 element diff。
  /// Key 供测试断言缓存命中（实例 identity）。
  Widget _cachedTagLayer() => _tagLayerCache ??= RepaintBoundary(
    key: ValueKey('settings-l0-boundary-${_selected.name}'),
    child: _TagLayer(selected: _selected, onTapTab: _onTagTapped),
  );

  /// L1 内容层缓存取用 — 同上；AnimatedSwitcher + 当前分区内容子树。
  Widget _cachedContentLayer() => _contentLayerCache ??= RepaintBoundary(
    key: ValueKey('settings-l1-boundary-${_selected.name}'),
    child: _ContentLayer(
      selected: _selected,
      services: widget.services,
      generalEligible: _generalEligible,
      rowsFocusNode: _rowsFocusNode,
      audioRowsFocusNode: _audioRowsFocusNode,
      scrollFor: _scrollFor,
      onScrolled: _onContentScrolled,
    ),
  );

  /// locale 门 — Localizations.localeOf 注册依赖，语言切换（App 级重建）
  /// 触发本 build 后此处失缓存，防缓存内 l10n 字符串陈旧。
  void _gateCachesByLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (_layerCacheLocale == locale) return;
    _layerCacheLocale = locale;
    _invalidateLayerCaches();
  }

  /// 面板内容 — 标题行 + 两层叠放，整体约束到可读宽度并居中.
  Widget _buildContent(BuildContext context) {
    // Live signal is outside content caches and outgoing switcher children.
    _generalEligible.value =
        widget.visible &&
        _level == _PanelLevel.content &&
        _selected == _SettingsTab.general;
    final l10n = AppLocalizations.of(context);
    _gateCachesByLocale(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header 重绘隔离 — backOpacity FadeTransition 与层动画并行期间
        // 只重录 header 子层, 不连带 tag/内容层 (v0.0.8.2 渲染优化).
        RepaintBoundary(
          child: _PanelHeader(
            l10n: l10n,
            onBack: _backToTags,
            onClose: widget.onClose,
            onPromote: widget.onPromote,
            showBack: _level == _PanelLevel.content,
            backOpacity: _motion.layerEase,
          ),
        ),
        Expanded(
          child: _LayerStack(
            visible: widget.visible,
            level: _level,
            motion: _motion,
            tagLayer: _cachedTagLayer(),
            contentLayer: _cachedContentLayer(),
          ),
        ),
      ],
    );

    // 宽窗口下面板矩形由工作区公式撑到 960px+；内容层约束到可读宽度并
    // 居中，避免「标签—控件」被拉散、滑块变成超长跑道。面板矩形本身
    // 不动，只有内容排版收窄 (MD3 max-measure)。
    return Align(
      child: ConstrainedBox(
        key: const ValueKey('settings-content-constraint'),
        constraints: const BoxConstraints(
          maxWidth: Tokens.settingsContentMaxWidth,
        ),
        child: content,
      ),
    );
  }
}
