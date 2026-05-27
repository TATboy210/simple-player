import 'package:flutter/widgets.dart';

import '../../window/window_lifecycle.dart';

/// Mixin for [State] — 自动订阅 [WindowLifecycleBus.isOperating]，
/// 提供 [isWindowOperating] 供子类在 Ticker 生命周期管理中使用。
///
/// 用法：
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleTickerProviderStateMixin, ResizeAwareTickerMixin {
///   void _syncTicker() {
///     final shouldRun = !isWindowOperating && otherCondition;
///     // ...
///   }
/// }
/// ```
mixin ResizeAwareTickerMixin<T extends StatefulWidget> on State<T> {
  bool _isWindowOperating = false;

  /// 窗口正在被用户操作（resize 或 move）时为 true
  bool get isWindowOperating => _isWindowOperating;

  @override
  void initState() {
    super.initState();
    _isWindowOperating = WindowLifecycleBus.instance.isOperating.value;
    WindowLifecycleBus.instance.isOperating.addListener(_onOperatingChanged);
  }

  void _onOperatingChanged() {
    final val = WindowLifecycleBus.instance.isOperating.value;
    if (_isWindowOperating != val) {
      setState(() => _isWindowOperating = val);
      onWindowOperatingChanged(val);
    }
  }

  /// 子类可覆写，在 resize/move 状态变化时同步 Ticker
  void onWindowOperatingChanged(bool operating) {}

  @override
  void dispose() {
    WindowLifecycleBus.instance.isOperating.removeListener(_onOperatingChanged);
    super.dispose();
  }
}
