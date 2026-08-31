import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import '../../kernel/utils/debug_exporter.dart';
import '../../l10n/app_localizations.dart';

/// 快捷键定义 — KeyboardHandler 和帮助对话框共享的单一数据源
///
/// 每个条目: (按键显示文本, 功能描述)
/// 新增快捷键时必须同时更新此列表和 KeyboardHandler._dispatchKeyEvent。
List<(String, String)> shortcutDefinitions(AppLocalizations l10n) => [
  ('Space', l10n.shortcutPlayPause),
  ('← / →', l10n.shortcutSeek),
  ('↑ / ↓', l10n.shortcutVolume),
  ('ESC', l10n.shortcutExitFullscreen),
  ('M', l10n.shortcutMute),
  ('O', l10n.shortcutOpenFile),
  ('S', l10n.shortcutSubtitle),
  ('] / [', l10n.shortcutSubtitleDelay),
  ('F1 / ?', l10n.shortcutHelp),
  ('媒体键', l10n.shortcutMediaKeys),
];

/// 键盘快捷键包装器 — 支持自定义绑定
///
/// Space → 播放/暂停 | ← → 后退/前进 5s | ↑ ↓ → 音量 ±5%
/// M → 静音 | O → 打开文件 | S → 字幕开关 | ESC → 退出全屏
/// ]/[ → 字幕延迟 ± | F1 → 帮助 | MediaPlayPause → 媒体播放键
///
/// 按键分发是**双路径**的（G-03-3，修复 UAT「按 F1 没用」）：
/// - **焦点路径**（主路径）：[Focus] 包装 child，按键沿焦点链冒泡到达，
///   语义与改造前完全一致（既有套件零改动回归）；
/// - **全局回退路径**：State 于 initState 注册
///   [HardwareKeyboard.instance.addHandler]，仅当主焦点滞留在 handler 焦点
///   子树之外（dead-keyboard 态：primaryFocus 为 null / 滞留框架 scope /
///   附着根 scope / 外部 Focus）时接管 —— 修复全屏进出循环后焦点回落
///   边界造成的快捷键整体失聪。守卫矩阵见
///   test/widget/player/keyboard_handler_global_dispatch_test.dart：
///   Slider/播放列表面板/对话框/文本框内的按键一律放行，不吞键。
///
/// [customBindings] 覆盖默认按键映射 (action → LogicalKeyboardKey.keyName)
class KeyboardHandler extends StatefulWidget {
  const KeyboardHandler({
    super.key,
    required this.child,
    this.customBindings = const {},
    this.onPlayPause,
    this.onSeekBackward,
    this.onSeekForward,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onToggleFullscreen,
    this.onToggleMute,
    this.onOpenFile,
    this.onToggleSubtitle,
    this.onExitFullscreen,
    this.onShowHelp,
    this.onSubtitleDelayForward,
    this.onSubtitleDelayBackward,
    this.onMediaPlayPause,
  });

  final Widget child;
  final Map<String, String> customBindings;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onToggleMute;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleSubtitle;
  final VoidCallback? onExitFullscreen;
  final VoidCallback? onShowHelp;
  final VoidCallback? onSubtitleDelayForward;
  final VoidCallback? onSubtitleDelayBackward;
  final VoidCallback? onMediaPlayPause;

  @override
  State<KeyboardHandler> createState() => _KeyboardHandlerState();
}

class _KeyboardHandlerState extends State<KeyboardHandler> {
  /// handler 自身焦点节点 —— 显式字段（原内部匿名），供回退守卫比对主焦点
  /// 身份与后代链；dispose 时释放。
  final FocusNode _focusNode = FocusNode(debugLabel: 'KeyboardHandler');

  /// handler 自身所在的 ModalRoute —— didChangeDependencies 捕获，用于区分
  /// 「自路由 scope 滞留（死键盘，接管）」与「其他路由（对话框/全屏 route，
  /// 该路由的控件自己消费按键，放行）」。
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    // 全局回退入口（G-03-3）：HardwareKeyboard handler 先于焦点分发运行。
    // 注册/注销在 dispose 严格配对，测试间零泄漏。
    HardwareKeyboard.instance.addHandler(_handleFallbackKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleFallbackKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleFocusedKeyEvent,
      child: widget.child,
    );
  }

  /// 焦点路径入口 —— 按键经焦点链冒泡到达（主路径，语义与改造前一致）。
  KeyEventResult _handleFocusedKeyEvent(FocusNode node, KeyEvent event) {
    return _dispatchKeyEvent(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  /// 全局回退入口（G-03-3）—— 仅当焦点链无法送达 handler 时接管。
  ///
  /// HardwareKeyboard handler 先于 FocusManager 分发运行，故守卫必须放行
  /// 一切「焦点分发能自洽消费」的按键，否则会抢在 Slider/面板/对话框前面
  /// 吞键。守卫判定顺序：
  /// 1. 仅 KeyDownEvent（与焦点路径一致，KeyUp/KeyRepeat 放行）；
  /// 2. 文本编辑守卫：主焦点位于 EditableText 焦点链内 → 放行；
  /// 3. 主焦点是本 handler 焦点节点自身或后代 → 放行（焦点分发上行必经
  ///    本 handler，不会死键）；
  /// 4. 主焦点位于其他路由（ModalRoute 祖先存在且非本 handler 路由）→
  ///    放行 —— 对话框内容/全屏 controls 等自行消费各自按键；
  /// 5. 其余接管：primaryFocus 为 null、滞留自路由（scope 或非后代节点，
  ///    分发上行不可达本 handler，必死）、无任何路由祖先（外部 Focus/根
  ///    Overlay 节点）。
  bool _handleFallbackKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final primary = FocusManager.instance.primaryFocus;
    final bool isHelpKey =
        event.logicalKey == LogicalKeyboardKey.f1 ||
        (event.logicalKey == LogicalKeyboardKey.slash &&
            event.character == '?');

    if (_isTextEditingFocused()) {
      if (isHelpKey) _logFallbackBypass('text-editing-guard', primary);
      return false;
    }

    if (primary != null) {
      if (_isInHandlerSubtree(primary)) {
        if (isHelpKey) {
          _logFallbackBypass('handler-subtree-focus-dispatch', primary);
        }
        return false;
      }
      final primaryContext = primary.context;
      final primaryRoute = primaryContext == null
          ? null
          : ModalRoute.of(primaryContext);
      if (primaryRoute != null && !identical(primaryRoute, _route)) {
        if (isHelpKey) _logFallbackBypass('foreign-route-focus', primary);
        return false;
      }
    }

    _logFallbackTakeover(primary, event);
    return _dispatchKeyEvent(event);
  }

  /// 主焦点是否位于文本编辑焦点链内 —— 文本输入守卫。
  ///
  /// 仅查 `primaryFocus.context.widget is EditableText` 在 TextField 上永不
  /// 匹配（TextField 的焦点节点由内部 `Focus` 件附着，context.widget 是
  /// Focus 包装件而非 EditableText，已探针证实），故补祖先查找分支：沿
  /// widget 祖先链找到 EditableText 即视为编辑中。两路分发共用。
  bool _isTextEditingFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// [node] 是否为本 handler 焦点节点自身或其后代（沿 parent 链上溯比对
  /// 身份）。
  bool _isInHandlerSubtree(FocusNode node) {
    FocusNode? current = node;
    while (current != null) {
      if (identical(current, _focusNode)) return true;
      current = current.parent;
    }
    return false;
  }

  /// 共享按键分发 —— 焦点路径与回退路径的**唯一**匹配实现，保证两路按键
  /// 语义永不漂移。返回 true 表示命中并已触发回调。
  bool _dispatchKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // 不拦截文本输入框的按键事件
    if (_isTextEditingFocused()) return false;

    final key = event.logicalKey;

    if (_keyMatches(key, 'playPause', LogicalKeyboardKey.space)) {
      widget.onPlayPause?.call();
      return true;
    }
    if (_keyMatches(key, 'seekBackward', LogicalKeyboardKey.arrowLeft)) {
      widget.onSeekBackward?.call();
      return true;
    }
    if (_keyMatches(key, 'seekForward', LogicalKeyboardKey.arrowRight)) {
      widget.onSeekForward?.call();
      return true;
    }
    if (_keyMatches(key, 'volumeUp', LogicalKeyboardKey.arrowUp)) {
      widget.onVolumeUp?.call();
      return true;
    }
    if (_keyMatches(key, 'volumeDown', LogicalKeyboardKey.arrowDown)) {
      widget.onVolumeDown?.call();
      return true;
    }
    if (_keyMatches(key, 'mute', LogicalKeyboardKey.keyM)) {
      widget.onToggleMute?.call();
      return true;
    }
    if (_keyMatches(key, 'openFile', LogicalKeyboardKey.keyO)) {
      widget.onOpenFile?.call();
      return true;
    }
    if (_keyMatches(key, 'subtitle', LogicalKeyboardKey.keyS)) {
      widget.onToggleSubtitle?.call();
      return true;
    }
    if (_keyMatches(key, 'exitFullscreen', LogicalKeyboardKey.escape)) {
      widget.onExitFullscreen?.call();
      return true;
    }
    // F 键切换全屏 — callback (player_keyboard_actions.onToggleFullscreen) 已修症状④:
    // enter 用 videoKey.enterFullscreen; exit 直接 rootNavigator.maybePop
    // (窗口态 key 的 toggleFullscreen/exitFullscreen 受 isFullscreen 守卫失效).
    // TODO: 补 shortcutDefinitions + l10n.shortcutFullscreen 以在帮助面板显示.
    if (_keyMatches(key, 'toggleFullscreen', LogicalKeyboardKey.keyF)) {
      widget.onToggleFullscreen?.call();
      return true;
    }
    if (_keyMatches(key, 'help', LogicalKeyboardKey.f1) ||
        (key == LogicalKeyboardKey.slash && event.character == '?')) {
      widget.onShowHelp?.call();
      return true;
    }

    // FEAT-04: Subtitle timing
    if (_keyMatches(
      key,
      'subtitleDelayForward',
      LogicalKeyboardKey.bracketRight,
    )) {
      widget.onSubtitleDelayForward?.call();
      return true;
    }
    if (_keyMatches(
      key,
      'subtitleDelayBackward',
      LogicalKeyboardKey.bracketLeft,
    )) {
      widget.onSubtitleDelayBackward?.call();
      return true;
    }

    // 调试快捷键: Ctrl+Shift+D 导出全部调试数据（FEAT 既有能力，保留）
    if (kDebugMode &&
        key == LogicalKeyboardKey.keyD &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      unawaited(_exportDebugData());
      return true;
    }

    // 系统媒体播放键固定映射，不受自定义快捷键配置影响。
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      widget.onMediaPlayPause?.call();
      return true;
    }

    return false;
  }

  /// 检查按键是否匹配指定动作（优先自定义绑定，否则使用默认按键）
  /// customBindings 存储 keyId 字符串
  bool _keyMatches(
    LogicalKeyboardKey key,
    String action,
    LogicalKeyboardKey defaultKey,
  ) {
    if (widget.customBindings.isEmpty) return key == defaultKey;
    final bound = widget.customBindings[action];
    if (bound == null) return key == defaultKey;
    return key.keyId.toString() == bound;
  }

  /// 导出调试数据到文件 (Ctrl+Shift+D)。
  ///
  /// 提取为 async 方法以用 await 替代 .then 链 (DCM prefer-async-await)。
  Future<void> _exportDebugData() async {
    final path = await DebugExporter.saveToFile();
    if (path != null) {
      developer.log('Debug data saved to: $path', name: 'Debug');
    }
  }

  /// 回退接管埋点（G-03-3）—— dead-keyboard 态实际发生时留证，供实机
  /// error.log 回溯「按键曾经到达」。以 [KernelLoggerImpl.isInitialized]
  /// 探针守卫（WR-02 先例）：测试环境不 init logger 也绝不抛 StateError。
  void _logFallbackTakeover(FocusNode? primary, KeyEvent event) {
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.d(
      '键盘全局回退接管：焦点链无法送达 handler，经 HardwareKeyboard 分发',
      context: <String, Object?>{
        'key': event.logicalKey.keyLabel,
        'primaryFocus': _describeFocusNode(primary),
      },
    );
  }

  /// 回退放行埋点 —— F1 到达回退入口但被守卫放行时留证（焦点路径将处理
  /// 或其他路由自洽消费），与接管埋点共同构成完整的 F1 观测链。
  void _logFallbackBypass(String reason, FocusNode? primary) {
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.d(
      'F1 到达键盘回退入口但被守卫放行：$reason',
      context: <String, Object?>{
        'reason': reason,
        'primaryFocus': _describeFocusNode(primary),
      },
    );
  }

  /// 焦点节点的稳定描述（日志 context 用）—— 避免在未初始化/脱离态访问
  /// context 抛错。
  String _describeFocusNode(FocusNode? node) {
    if (node == null) return 'null';
    final context = node.context;
    if (context == null) return node.debugLabel ?? node.runtimeType.toString();
    return context.widget.runtimeType.toString();
  }
}
