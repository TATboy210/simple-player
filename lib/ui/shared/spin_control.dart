// SpinControl — Steam 风格水平选择器控件（D-08/D-09/D-03/D-06/D-07/D-10）。
//
// 左箭头 + 动画值显示 + 右箭头，支持键盘 D-pad 左右键调整。
// 用于设置面板中的枚举选项切换（如语言、渲染器等）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Steam 风格水平选择器 — [left arrow] [animated value] [right arrow]
///
/// 用于设置面板中的枚举选项切换。支持鼠标点击箭头和键盘
/// ArrowLeft/ArrowRight 调整值（D-10），边界箭头变灰（D-03）。
///
/// ```dart
/// SpinControl(
///   options: ['zh', 'en'],
///   currentIndex: 0,
///   onChanged: (i) => setState(() => _index = i),
///   formatValue: (v) => v == 'zh' ? '中文' : 'English',
/// )
/// ```
class SpinControl extends StatefulWidget {
  /// 可选值列表（D-08）
  final List<String> options;

  /// 当前选中索引
  final int currentIndex;

  /// 选择变更回调
  final ValueChanged<int> onChanged;

  /// 自定义值格式化器（D-09），传入 raw option 返回显示文本
  final String Function(String)? formatValue;

  /// 用于测试定位的可选 Key
  final Key? focusKey;

  const SpinControl({
    super.key,
    required this.options,
    required this.currentIndex,
    required this.onChanged,
    this.formatValue,
    this.focusKey,
  });

  @override
  State<SpinControl> createState() => _SpinControlState();
}

class _SpinControlState extends State<SpinControl> {
  /// 滑动方向：+1 = 从右进入（点击右箭头），-1 = 从左进入（点击左箭头）
  int _slideDirection = 1;

  bool _focused = false;

  /// 是否在左边界（不可再左移）
  bool get _atLeftBoundary =>
      widget.options.isEmpty || widget.currentIndex <= 0;

  /// 是否在右边界（不可再右移）
  bool get _atRightBoundary =>
      widget.options.isEmpty ||
      widget.currentIndex >= widget.options.length - 1;

  /// 左箭头颜色 — 边界时变灰（D-03）
  Color get _leftArrowColor =>
      _atLeftBoundary ? Tokens.textTertiary : Tokens.textSecondary;

  /// 右箭头颜色 — 边界时变灰（D-03）
  Color get _rightArrowColor =>
      _atRightBoundary ? Tokens.textTertiary : Tokens.textSecondary;

  /// 格式化显示文本
  String get _displayText {
    if (widget.options.isEmpty) return '';
    final raw = widget.options[widget.currentIndex];
    return widget.formatValue?.call(raw) ?? raw;
  }

  /// 向左移动（减少索引）
  void _moveLeft() {
    if (_atLeftBoundary) return;
    setState(() => _slideDirection = -1);
    widget.onChanged(widget.currentIndex - 1);
  }

  /// 向右移动（增加索引）
  void _moveRight() {
    if (_atRightBoundary) return;
    setState(() => _slideDirection = 1);
    widget.onChanged(widget.currentIndex + 1);
  }

  /// 处理键盘事件 — ArrowLeft/ArrowRight 调整值（D-10）
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveLeft();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveRight();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      key: widget.focusKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKeyEvent,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          // 聚焦边框 — 非聚焦时同宽透明边框防止布局跳动
          border: Border.all(
            color: _focused ? Tokens.borderHighlight : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 左箭头
            _buildArrowButton(
              icon: Icons.chevron_left,
              color: _leftArrowColor,
              onTap: _moveLeft,
            ),
            // 值显示区域 — ClipRect + AnimatedSwitcher 水平滑入/滑出（D-06/D-07）
            // 固定宽度 100px，避免在 SettingRow 的 Row 中收到无界约束
            SizedBox(
              width: 100,
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: _buildSlideTransition,
                  child: Text(
                    _displayText,
                    key: ValueKey<String>(_displayText),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Tokens.textPrimary,
                      fontSize: Tokens.fontBody,
                    ),
                  ),
                ),
              ),
            ),
            // 右箭头
            _buildArrowButton(
              icon: Icons.chevron_right,
              color: _rightArrowColor,
              onTap: _moveRight,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建滑入/滑出过渡 — 根据方向决定新值从哪边进入（D-06）
  Widget _buildSlideTransition(Widget child, Animation<double> animation) {
    final offset = Tween<Offset>(
      begin: Offset(_slideDirection.toDouble(), 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: offset,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// 构建箭头按钮 — 32px 宽，InkWell hover/press 反馈
  Widget _buildArrowButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 32,
      height: 36,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        child: Center(
          child: Icon(icon, size: Tokens.iconMd, color: color),
        ),
      ),
    );
  }
}
