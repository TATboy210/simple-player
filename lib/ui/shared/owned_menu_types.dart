import 'package:material_ui/material_ui.dart';

/// 不可变动作项 — checked is informational, never a disabled radio choice.
class OwnedMenuEntry<T> {
  const OwnedMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.isEnabled = true,
    this.isChecked = false,
    this.isDestructive = false,
  });
  final T value;
  final String label;
  final IconData? icon;
  final bool isEnabled;
  final bool isChecked;
  final bool isDestructive;
}

/// 菜单结果 — null future result denotes cancellation, not a selected null value.
class OwnedMenuSelection<T> {
  const OwnedMenuSelection(this.value);
  final T value;
}
