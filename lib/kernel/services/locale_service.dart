import 'package:flutter/widgets.dart';

import '../persistence/settings_store.dart';

/// 语言服务 — 全局单例，持有当前 Locale 并自动持久化
///
/// 用法：
/// ```dart
/// await LocaleService.I.init();              // 启动时加载
/// LocaleService.I.setLocale('en');           // 切换语言
/// ValueListenableBuilder<Locale>(            // UI 监听
///   valueListenable: LocaleService.I.locale,
///   builder: (_, locale, _) => ...,
/// )
/// ```
class LocaleService {
  LocaleService._();

  /// Singleton instance accessor.
  static final LocaleService I = LocaleService._();

  /// Current locale. Notifies listeners on change.
  final ValueNotifier<Locale> locale = ValueNotifier(
    const Locale('zh'), // 默认中文 — 与 SettingsValidator.defaultLocale 保持一致
  );

  /// 从持久化存储加载语言设置
  Future<void> init() async {
    final code = await SettingsStore.loadLocale();
    locale.value = Locale(code);
  }

  /// 切换语言并持久化
  void setLocale(String code) {
    locale.value = Locale(code);
    SettingsStore.saveLocale(code);
  }

  /// Releases resources. Call when service is no longer needed.
  void dispose() => locale.dispose();
}
