part of 'settings_panel.dart';

/// 面板级键盘（XMB 交叉模型）— 与 State 解耦的按键分发 mixin。
///
/// 返回 handled 阻断冒泡（防外层 seek/音量/暂停泄漏），Esc 刻意 ignored
/// （冒泡 → 宿主退出全屏）。依赖的导航状态与动作由宿主 State 实现。
mixin _PanelKeyHandling on State<SettingsPanel> {
  /// 当前分区.
  _SettingsTab get _selected;

  /// 当前层级.
  _PanelLevel get _level;

  /// General 分区行导航焦点.
  FocusNode get _rowsFocusNode;

  /// Audio 分区行导航焦点.
  FocusNode get _audioRowsFocusNode;

  /// 切换分区（同时失效缓存、发布导航）.
  void _changeSelected(_SettingsTab tab);

  /// L0 → L1.
  void _enterContent();

  /// L1 → L0.
  void _backToTags();

  /// 分区 → 行导航焦点节点；video/about 无行导航返回 null.
  FocusNode? _rowsNodeFor(_SettingsTab tab) => switch (tab) {
    _SettingsTab.general => _rowsFocusNode,
    _SettingsTab.audio => _audioRowsFocusNode,
    _SettingsTab.video => null,
    _SettingsTab.about => null,
  };

  /// 是否「确认」类按键 — Enter / 小键盘 Enter / Space.
  static bool _isActivateKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space;

  /// 是否纵向方向键.
  static bool _isVerticalArrow(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown;

  /// 面板级按键 — 返回 handled 阻断冒泡，Esc 刻意 ignored.
  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    // 防线：焦点滞留隐藏面板时绝不吞键（宿主负责归还焦点，此处兜底）.
    if (!widget.visible) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    return _level == _PanelLevel.tags
        ? _handleTagsLevelKey(key)
        : _handleContentLevelKey(key);
  }

  /// L0 — ↑↓ 在 tag 列间移动（enabled 集合内到头即停），→ 或 Enter/Space
  /// 进入内容层；← handled 空操作（ignored 会冒泡成 seek）；Esc 冒泡退出全屏.
  KeyEventResult _handleTagsLevelKey(LogicalKeyboardKey key) {
    if (_isVerticalArrow(key)) {
      final dir = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final index = _enabledTabs.indexOf(_selected);
      final next = (index + dir).clamp(0, _enabledTabs.length - 1);
      if (next != index) _changeSelected(_enabledTabs[next]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isActivateKey(key)) {
      _enterContent();
      return KeyEventResult.handled;
    }
    // ← handled 空操作（挡 seek 泄漏）；Esc/其余 — 冒泡（Esc 退出全屏）.
    return key == LogicalKeyboardKey.arrowLeft
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  /// L1 — → handled 空操作（用户裁决 2026-10-09：详情页内 → 不再切分区，
  /// 进出详情只经 →/Enter 进、← 退）；← 返回 tag 层；↑↓/Enter/Space 交给
  /// rows 节点（General/audio 后代先消费，未聚焦则聚焦下沉行级）；
  /// video/about 分区同键 handled 空操作（防泄漏）；Esc 冒泡宿主退出全屏
  /// （返回专属 ← 键）.
  KeyEventResult _handleContentLevelKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight) {
      // 空操作但 handled — 防止 → 冒泡成 seek；分区切换仅发生在 L0.
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _backToTags();
      return KeyEventResult.handled;
    }
    if (_isVerticalArrow(key) || _isActivateKey(key)) {
      // 行导航分区（General/audio）焦点滞留面板级时下沉行级；
      // video/about 维持 handled 空操作（键盘不可达分区防泄漏）.
      final rowsNode = _rowsNodeFor(_selected);
      if (rowsNode != null && !rowsNode.hasFocus) rowsNode.requestFocus();
      return KeyEventResult.handled;
    }
    // Esc/其余 — 冒泡（Esc 经宿主退出全屏）.
    return KeyEventResult.ignored;
  }
}
