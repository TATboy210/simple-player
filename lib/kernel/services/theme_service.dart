import 'package:flutter/material.dart';

import '../persistence/settings_store.dart';

/// 主题服务 — 全局单例，持有当前主题索引并自动持久化
///
/// 用法：
/// ```dart
/// await ThemeService.I.init();               // 启动时加载
/// ThemeService.I.setTheme(1);                // 切换主题
/// MaterialApp(theme: ThemeService.I.currentTheme)
/// ```
class ThemeService {
  ThemeService._();
  static final ThemeService I = ThemeService._();

  static const accents = [
    Color(0xFF2C58F4), // Midnight
    Color(0xFF00B4D8), // Ocean
    Color(0xFF2D6A4F), // Forest
  ];

  final ValueNotifier<int> themeIndex = ValueNotifier(0);

  ThemeData get currentTheme => _buildTheme(themeIndex.value);
  Color get currentAccent =>
      accents[themeIndex.value.clamp(0, accents.length - 1)];

  /// 从持久化存储加载主题设置
  Future<void> init() async {
    final index = await SettingsStore.loadThemeIndex();
    themeIndex.value = index;
  }

  /// 切换主题并持久化
  void setTheme(int index) {
    themeIndex.value = index.clamp(0, accents.length - 1);
    SettingsStore.saveThemeIndex(themeIndex.value);
  }

  static ThemeData _buildTheme(int index) {
    final accent = accents[index.clamp(0, accents.length - 1)];
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(primary: accent, secondary: accent),
    );
  }

  void dispose() => themeIndex.dispose();
}
