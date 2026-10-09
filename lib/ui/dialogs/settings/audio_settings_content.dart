// ignore_for_file: avoid-unnecessary-stateful-widgets
/// 「音频」分区内容 (v0.0.6) — 音频延迟 / 字幕延迟 (毫秒级 SpinControl).
///
/// 写入通道: [AppSettingsService] — 引擎 (mpv audio-delay/sub-delay) +
/// 落盘; file-scoped 属性随新文件装载自动重放, 跨文件保持.
/// EQ 不在本期范围 (v0.0.6 用户裁决)。
///
/// 纵轴键盘导航 (v0.0.12 261009-upn)：宿主面板注入 [rowsFocusNode] 后与
/// General 同模式 — ↑↓ 在两行间移动焦点（首尾回绕）；Enter/Space 激活 =
/// 交焦当前行的 SpinControl 外壳焦点，←→ 在该层步进延迟值（SpinControl
/// D-10 同语义：边界即停）；↑↓ 随时把焦点收回行级（General「语言按钮
/// 权限移交」同款）；← 冒泡面板返回 tag 层。行高亮 = bgHover 常亮 +
/// 行首 accent 竖条（复用 General `_SettingsRow` 语法）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/spin_control.dart';
import '../../theme/tokens.dart';

/// 延迟可调范围 (毫秒) 与步长 — ±1s / 50ms 步进, 覆盖常见音画偏移场景.
const _delayMinMs = -1000;
const _delayMaxMs = 1000;
const _delayStepMs = 50;

/// 「音频」分区内容 — 订阅权威服务的延迟 revision。
/// Panel and keyboard setters refresh every mounted route without duplicating values.
class AudioSettingsContent extends StatefulWidget {
  const AudioSettingsContent({
    super.key,
    required this.settings,
    this.rowsFocusNode,
    this.scrollController,
  });

  /// 由当前设置 route 拥有，不跨 route 共享附着。
  final ScrollController? scrollController;

  final AppSettingsService settings;

  /// 行导航焦点节点 — 面板注入（↑↓/Enter 消费者）；null 时不挂键盘
  /// 导航（直 pump 测试退路，行 hover/点击不受影响）.
  final FocusNode? rowsFocusNode;

  @override
  State<AudioSettingsContent> createState() => _AudioSettingsContentState();
}

class _AudioSettingsContentState extends State<AudioSettingsContent> {
  /// 键盘行焦点索引 — 0 音频延迟 / 1 字幕延迟（行序恒定）.
  int _focusedRow = 0;

  /// 行级焦点是否在树 — 行高亮条件之一（Focus.hasFocus 含后代语义：
  /// 值控件外壳聚焦时保持 true，行高亮不闪断）.
  bool _rowsFocused = false;

  /// 行值控件外壳焦点 — Enter 激活的交焦落点；←→ 步进在此层消费
  /// （`_DelayRow._handleValueKeyEvent`），↑↓/Enter ignored 冒泡回行级.
  late final List<FocusNode> _valueFocusNodes = [
    FocusNode(debugLabel: 'audio-delay-row-value'),
    FocusNode(debugLabel: 'subtitle-delay-row-value'),
  ];

  /// 行数 — 两行延迟恒显（服务注入在分区级把关），键盘导航行序恒定.
  int get _rowCount => 2;

  /// 延迟毫秒 → SpinControl 索引 (双向线性映射).
  int _msToIndex(int ms) =>
      ((ms - _delayMinMs) ~/ _delayStepMs).clamp(0, _optionCount - 1);

  /// SpinControl 索引 → 延迟毫秒.
  int _indexToMs(int index) => _delayMinMs + index * _delayStepMs;

  static const _optionCount = ((_delayMaxMs - _delayMinMs) ~/ _delayStepMs) + 1;

  /// SpinControl 选项 — 类加载单次初始化 (v0.0.8.2: 旧实现每次 build
  /// 分配 41 字符串 × 2 行; 稳定列表命中 identical 短路重建).
  static final _delayOptions = List<String>.generate(
    _optionCount,
    (i) => '${_delayMinMs + i * _delayStepMs}',
  );

  @override
  void dispose() {
    for (final node in _valueFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// 纵轴按键 — ↑↓ 回绕移动焦点行（并把焦点从值控件收回行级，General
  /// 「权限移交」同款）；Enter/Space 激活 = 交焦当前行值控件；其余
  /// ignored（← 冒泡给面板返回 tag 层）.
  KeyEventResult _handleRowsKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      // 方向键导航随时收回行级权威 — 值控件子模式即刻退出.
      widget.rowsFocusNode?.requestFocus();
      setState(() {
        final dir = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _focusedRow = (_focusedRow + dir + _rowCount) % _rowCount;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _activateRow(_focusedRow);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 行激活 — Enter/Space 交焦当前行值控件（SpinControl 外壳焦点）；
  /// 延迟行无菜单/开关，值步进专属 ←→（此后由值控件层消费）.
  void _activateRow(int index) {
    if (index < 0 || index >= _valueFocusNodes.length) return;
    _valueFocusNodes[index].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = _delayOptions;

    return Focus(
      focusNode: widget.rowsFocusNode,
      onFocusChange: (focused) => setState(() => _rowsFocused = focused),
      onKeyEvent: _handleRowsKeyEvent,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.settings.delayRevision,
        builder: (_, revision, _) => Padding(
          padding: const EdgeInsets.all(Tokens.spLg),
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Tokens.spXs,
              children: [
                _DelayRow(
                  label: l10n.audioDelay,
                  options: options,
                  currentIndex: _msToIndex(widget.settings.audioDelayMs),
                  formatValue: (raw) => '$raw ms',
                  isFocused: _rowsFocused && _focusedRow == 0,
                  valueFocusNode: _valueFocusNodes[0],
                  // Service revision is the sole invalidation for all panels.
                  onChanged: (i) =>
                      widget.settings.setAudioDelayMs(_indexToMs(i)),
                ),
                _DelayRow(
                  label: l10n.subtitleDelay,
                  options: options,
                  currentIndex: _msToIndex(widget.settings.subtitleDelayMs),
                  formatValue: (raw) => '$raw ms',
                  isFocused: _rowsFocused && _focusedRow == 1,
                  valueFocusNode: _valueFocusNodes[1],
                  onChanged: (i) =>
                      widget.settings.setSubtitleDelayMs(_indexToMs(i)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 延迟设置行 — label + SpinControl.
///
/// [isFocused] 键盘焦点行高亮（bgHover 常亮 + 行首 accent 竖条，General
/// `_SettingsRow` 同语法）；[valueFocusNode] 为行值控件外壳焦点 — 聚焦时
/// ←→ 步进延迟值（与 SpinControl 自身 D-10 同语义：边界即停）。
class _DelayRow extends StatelessWidget {
  const _DelayRow({
    required this.label,
    required this.options,
    required this.currentIndex,
    required this.formatValue,
    required this.onChanged,
    this.isFocused = false,
    this.valueFocusNode,
  });

  final String label;
  final List<String> options;
  final int currentIndex;
  final String Function(String) formatValue;
  final ValueChanged<int> onChanged;

  /// 键盘焦点行 — 恒亮高亮（与 hover 同色系并存）.
  final bool isFocused;

  /// 值控件外壳焦点节点 — null 时无键盘步进（指针路径不受影响）.
  final FocusNode? valueFocusNode;

  /// ←→ 值步进 — 与 SpinControl._moveLeft/_moveRight 同语义（边界即停），
  /// 经同一 [onChanged] 写服务（值语义单源，不在本层另立写通道）.
  KeyEventResult _handleValueKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    return switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _step(-1),
      LogicalKeyboardKey.arrowRight => _step(1),
      // ↑↓/Enter/Space ignored — 冒泡回行级 Focus（行导航/激活）.
      _ => KeyEventResult.ignored,
    };
  }

  /// 步进一格 — 越界即停（D-03 边界变灰语义的键盘侧），吞键防泄漏.
  KeyEventResult _step(int delta) {
    final next = currentIndex + delta;
    if (next < 0 || next >= options.length) {
      return KeyEventResult.handled;
    }
    onChanged(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        padding: const EdgeInsets.symmetric(
          vertical: 3,
          horizontal: Tokens.spSm,
        ),
        decoration: BoxDecoration(
          color: isFocused ? Tokens.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          children: [
            // 焦点指示竖条 — 恒 2px 槽位（透明→accent 点亮），防布局跳动
            // （General _SettingsRow 同款语法）.
            AnimatedContainer(
              duration: const Duration(milliseconds: Tokens.durationFast),
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: isFocused ? Tokens.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
            // 值控件外壳焦点 — Enter 激活行的交焦落点；自身仅消费 ←→，
            // 其余键冒泡回行级 Focus（面板级 ← 返回 tag 层契约不变）.
            Focus(
              focusNode: valueFocusNode,
              onKeyEvent: (_, event) => _handleValueKeyEvent(event),
              child: SpinControl(
                options: options,
                currentIndex: currentIndex,
                formatValue: formatValue,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
